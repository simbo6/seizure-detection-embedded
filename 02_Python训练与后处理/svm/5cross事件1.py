import pandas as pd
import h5py
import numpy as np
from datetime import datetime, timedelta
import os
import openpyxl
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import unicodedata

# ----------------------
# 基础配置（适配五折交叉验证）
# ----------------------
merge_interval = 300  # 秒，事件合并阈值
print(f"初始化完成: 事件合并阈值={merge_interval}秒")
# 网格搜索参数（新增均值滤波窗口大小）
thresholds = [0.7]
min_lengths = [5]
filter_windows = [4]  # 均值滤波窗口大小超参数
print(f"网格搜索参数: thresholds={thresholds}, min_lengths={min_lengths}, filter_windows={filter_windows}\n")
# 【删除】手动FOLD_TOTAL_DURATION，改为每折动态计算总时长
# 【新增】时间段定义
def get_time_period(dt):
    """判断时间属于白天还是晚上：晚10点(22:00)到早6点(06:00)为晚上，其余为白天"""
    hour = dt.hour
    if 22 <= hour or hour < 6:
        return "晚上"
    else:
        return "白天"
# 【新增】均值滤波函数（从第一个代码迁移）
def forward_mean_filter(data, k=6):
    """
    前向均值滤波函数
    Args:
        data: 1D数组，待滤波数据
        k: 窗口大小，默认6
    Returns:
        filtered_data: 滤波后的数据
    """
    if len(data) < k:
        print(f"警告：数据长度({len(data)})小于滤波窗口大小({k})，返回原数据")
        return data.copy()
    filtered_data = data.copy()
    for t in range(k - 1, len(data)):
        window = data[t - k + 1: t + 1]
        filtered_data[t] = np.mean(window)
    return filtered_data
# ----------------------
# 核心功能函数（适配五折+时间段统计+区分患者/健康人+事件明细收集）
# ----------------------
def load_validation_data_for_fold(fold_num, base_path):
    """
    加载指定折的真实数据（适配五折交叉验证）
    Args:
        fold_num: 折数（1-5）
        base_path: 测试集主文件夹路径（ceshiji）
    """
    print(f"\n[步骤1/4] 读取第{fold_num}折真实数据...")
    # 拼接当前折的测试集路径
    fold_test_path = os.path.join(base_path, f"{fold_num}cross")
    test_file = os.path.join(fold_test_path, "combined_features_lab_z.mat")
    print(f"真实数据路径: {test_file}")
    with h5py.File(test_file, 'r') as f:
        # 读取all_lab并转置（修正MATLAB行列问题）
        dataset = f['all_lab'][()].T
        # 提取需要的列：label(0), id(1), people(2), time(3), quality(5), file_id(6)
        data = dataset[:, [0, 1, 2, 3, 5, 6]]
    # 创建DataFrame并指定列名
    true_df = pd.DataFrame(data, columns=['label', 'id', 'people', 'time', 'quality', 'file_id'])
    # 类型转换
    int_columns = ['id', 'file_id', 'people', 'quality']
    true_df[int_columns] = true_df[int_columns].astype(np.int64)
    true_df['time'] = true_df['time'].astype(np.float64).astype(np.int64)
    # 时间处理
    time_str = true_df['time'].astype(str).str.zfill(6)
    true_df['time'] = pd.to_datetime(time_str, format='%H%M%S', errors='coerce')
    true_df = true_df.dropna(subset=['time'])
    # 【新增】添加时间段列
    true_df['period'] = true_df['time'].apply(get_time_period)
    # 整体时长统计
    total_samples = len(true_df)
    total_duration_hours = total_samples * 2 / 3600
    # 患者(people=1) 时长拆分
    true_patient = true_df[true_df['people'] == 1].copy()
    day_samples_patient = len(true_patient[true_patient['period'] == '白天'])
    night_samples_patient = len(true_patient[true_patient['period'] == '晚上'])
    patient_day_h = day_samples_patient * 2 / 3600
    patient_night_h = night_samples_patient * 2 / 3600
    patient_total_h = patient_day_h + patient_night_h
    # 健康人(people=0) 时长拆分
    true_healthy = true_df[true_df['people'] == 0].copy()
    day_samples_healthy = len(true_healthy[true_healthy['period'] == '白天'])
    night_samples_healthy = len(true_healthy[true_healthy['period'] == '晚上'])
    healthy_day_h = day_samples_healthy * 2 / 3600
    healthy_night_h = night_samples_healthy * 2 / 3600
    healthy_total_h = healthy_day_h + healthy_night_h
    print(f"第{fold_num}折全部有效行数: {len(true_df)}, 总时长{total_duration_hours:.4f}h")
    print(f"【患者】总时长{patient_total_h:.4f}h | 白天{patient_day_h:.4f}h | 夜晚{patient_night_h:.4f}h")
    print(f"【健康人】总时长{healthy_total_h:.4f}h | 白天{healthy_day_h:.4f}h | 夜晚{healthy_night_h:.4f}h")
    duration_info = {
        "total_all_h": total_duration_hours,
        "day_all_h": (patient_day_h + healthy_day_h),
        "night_all_h": (patient_night_h + healthy_night_h),
        "patient_total_h": patient_total_h,
        "patient_day_h": patient_day_h,
        "patient_night_h": patient_night_h,
        "healthy_total_h": healthy_total_h,
        "healthy_day_h": healthy_day_h,
        "healthy_night_h": healthy_night_h
    }
    return true_df, true_patient, true_healthy, duration_info
def load_prediction_data_for_fold(fold_num, pred_base_path, filter_window=6):
    """
    加载指定折的预测数据（适配五折交叉验证）
    Args:
        fold_num: 折数（1-5）
        pred_base_path: 预测结果保存的根路径（trainsvm_cv_results）
        filter_window: 均值滤波窗口大小
    """
    print(f"\n[步骤2/4] 读取第{fold_num}折预测数据...")
    fold_pred_path = os.path.join(pred_base_path, f"fold_{fold_num}")
    pred_file = os.path.join(fold_pred_path, f"fold_{fold_num}_predictions.csv")
    print(f"预测数据路径: {pred_file}")
    pred_df = pd.read_csv(pred_file)
    # 对预测概率进行均值滤波
    if 'filtered_proba' in pred_df.columns:
        pred_df['filtered_proba'] = forward_mean_filter(pred_df['filtered_proba'].values, k=filter_window)
        print(f"已对预测概率进行均值滤波，窗口大小: {filter_window}")
    print(f"第{fold_num}折预测数据加载完成，行数: {len(pred_df)}")
    return pred_df
def extract_events(df, value_column, threshold=0.5, min_length=6, is_pred=False, true_df=None):
    """
    事件提取函数（修复loc索引越界KeyError，改用iloc位置索引+边界校验 + 修复缩进错误）
    """
    print(f"\n开始提取事件 (is_pred={is_pred})...")
    print(f"参数: threshold={threshold}, min_length={min_length}")
    if is_pred and true_df is None:
        raise ValueError("true_df must be provided when is_pred=True")
    all_events = []
    # 按file_id分组处理
    for file_id, file_group in df.groupby('file_id'):
        file_group = file_group.reset_index(drop=True)
        # 判断是否为事件
        if is_pred:
            file_group['is_event'] = (file_group[value_column] >= threshold)
        else:
            file_group['is_event'] = (file_group[value_column] == 1)
        # 标记连续事件段
        file_group['event_group'] = (file_group['is_event'].astype(int).diff().ne(0)).cumsum()
        # 筛选有效事件段
        for group_id, event_group in file_group.groupby('event_group'):
            if not event_group['is_event'].all():
                continue
            if len(event_group) < min_length:
                continue
            # 预测事件过滤无效样本（核心修复：loc -> iloc 位置索引+边界判断）
            if is_pred:
                if len(event_group) > len(true_df):
                    event_group = event_group.iloc[:len(true_df)]
                indices = event_group.index
                # 边界校验，防止索引越界
                valid_indices = [idx for idx in indices if 0 <= idx < len(true_df)]
                if len(valid_indices) > 0:
                    labels = true_df.iloc[valid_indices]['label'].values
                    qualities = true_df.iloc[valid_indices]['quality'].values
                else:
                    labels = []
                    qualities = []
                invalid_mask = np.zeros(len(valid_indices), dtype=bool)
                if len(labels) > 0 and len(qualities) > 0:
                    invalid_mask = (labels == 0) & (qualities == 1)
                if np.any(invalid_mask):
                    continue
            # 事件起止、时段
            # 预测报警使用检测窗口最后一个2秒片段的时间；真实事件保持原始起止时间
            # 报警开始时间取检测窗口最后一个2秒片段的时间；结束时间在原结束时间基础上顺延2秒
            start_time = event_group['time'].max()
            end_time = start_time + timedelta(seconds=2)
            # 报警开始时间取检测窗口最后一个2秒片段的时间；结束时间在原结束时间基础上顺延2秒
            start_time = event_group['time'].max()
            end_time = start_time + timedelta(seconds=2)
            if is_pred:
                start_time = event_group['time'].max()
                end_time = start_time + timedelta(seconds=2)
            else:
                start_time = event_group['time'].min()
                end_time = event_group['time'].max()
            periods = event_group['period'].value_counts()
            main_period = periods.index[0] if not periods.empty else get_time_period(start_time)
            all_events.append({
                'id': event_group['id'].iloc[0],
                'start': start_time,
                'end': end_time,
                'file_id': file_id,
                'period': main_period,
                'duration': (end_time - start_time).total_seconds(),
                'people': event_group['people'].iloc[0]  # 新增分组标识，用于后续拆分
            })
    # 合并邻近事件
    if all_events:
        events_df = pd.DataFrame(all_events)
        events_df = events_df.sort_values(['id', 'file_id', 'start'])
        merged_events = []
        for (id_val, file_id_val), group in events_df.groupby(['id', 'file_id']):
            if group.empty:
                continue
            # 按时间排序
            group = group.sort_values('start')
            merged = [group.iloc[0].to_dict()]
            for _, row in group.iloc[1:].iterrows():
                # 以当前报警组第一次报警的开始时间计算5分钟抑制窗口
                current_event = merged[-1]
                time_diff = (row['start'] - current_event['start']).total_seconds()
                if time_diff <= merge_interval:
                    current_event['end'] = row['end']
                    current_event['duration'] = (current_event['end'] - current_event['start']).total_seconds()
                    periods = [current_event['period'], row['period']]
                    current_event['period'] = max(set(periods), key=periods.count)
                else:
                    merged.append(row.to_dict())
            group = group.sort_values('start')
            merged = [group.iloc[0].to_dict()]
            for _, row in group.iloc[1:].iterrows():
                # 以当前报警组第一次报警的开始时间计算5分钟抑制窗口
                current_event = merged[-1]
                time_diff = (row['start'] - current_event['start']).total_seconds()
                if time_diff <= merge_interval:
                    current_event['end'] = row['end']
                    current_event['duration'] = (current_event['end'] - current_event['start']).total_seconds()
                    periods = [current_event['period'], row['period']]
                    current_event['period'] = max(set(periods), key=periods.count)
                else:
                    merged.append(row.to_dict())
            merged_events.extend(merged)
        all_events = merged_events
    # 时段统计
    if all_events:
        events_df = pd.DataFrame(all_events)
        period_stats = events_df['period'].value_counts()
        print(f"事件时间段统计:")
        for period, count in period_stats.items():
            print(f"  {period}: {count} 个")
    print(f"共提取到 {len(all_events)} 个事件")
    return pd.DataFrame(all_events)
def match_events(true_events, pred_events, min_length=5):
    """事件匹配（仅患者使用，健康人无真实事件无需匹配）+ 事件明细收集"""
    print("\n开始事件匹配...")
    # 初始化事件明细列表
    event_details = []
    if true_events.empty:
        print("真实事件为空，无法进行匹配。")
        # 所有预测事件都是误报
        for pred_idx, pred_row in pred_events.iterrows():
            event_details.append({
                'hospital': '',
                'patient': pred_row['id'],
                'file': pred_row['file_id'],
                'fold': None,
                'event_class': '误报',
                'start_time': pred_row['start'].strftime('%H:%M:%S'),
                'end_time': pred_row['end'].strftime('%H:%M:%S'),
                'duration_seconds': pred_row['duration'],
                'delay_seconds': np.nan
            })
        matched = pd.DataFrame()
        fp = pred_events
        missed = true_events
        return matched, fp, missed, event_details
    else:
        true_events = true_events.copy()
        true_events['start_ts'] = true_events['start'].astype('int64')
        true_events['end_ts'] = true_events['end'].astype('int64')
        matched = []
        matched_true = set()
        matched_pred = set()
        for pred_idx, pred_row in pred_events.iterrows():
            pred_start = pred_row['start'].value
            pred_end = pred_row['end'].value
            candidates = true_events[
                (true_events['id'] == pred_row['id']) &
                (true_events['file_id'] == pred_row['file_id']) &
                (true_events['start_ts'] <= pred_end) &
                (true_events['end_ts'] >= pred_start)
            ]
            candidates = true_events[
                (true_events['id'] == pred_row['id']) &
                (true_events['file_id'] == pred_row['file_id']) &
                (true_events['start_ts'] <= pred_end) &
                # 允许预测发生在真实事件结束后30秒内
                (true_events['end_ts'] + 10 * 10 ** 9 >= pred_start)
            ]
            if not candidates.empty:
                true_match = candidates.iloc[0]
                # 计算延迟
                delays = (pd.to_datetime(pred_row['start'].strftime('%H:%M:%S'), format='%H:%M:%S') -
                          pd.to_datetime(true_match['start'].strftime('%H:%M:%S'), format='%H:%M:%S')).total_seconds()
                mean_delay = delays
                # 匹配成功，添加发作事件明细
                event_details.append({
                    'hospital': '',
                    'patient': pred_row['id'],
                    'file': pred_row['file_id'],
                    'fold': None,
                    'event_class': '发作',
                    'start_time': pred_row['start'].strftime('%H:%M:%S'),
                    'end_time': pred_row['end'].strftime('%H:%M:%S'),
                    'duration_seconds': pred_row['duration'],
                    'delay_seconds': mean_delay
                })
                matched.append({
                    'pred_id': pred_idx,
                    'pred_start': pred_row['start'].strftime('%H:%M:%S'),
                    'pred_end': pred_row['end'].strftime('%H:%M:%S'),
                    'true_start': true_match['start'].strftime('%H:%M:%S'),
                    'true_end': true_match['end'].strftime('%H:%M:%S'),
                    'id': pred_row['id'],
                    'file_id': pred_row['file_id'],
                    'period': pred_row['period'],
                    'duration': pred_row['duration']
                })
                matched_true.add(true_match.name)
                matched_pred.add(pred_idx)
            else:
                # 误报事件
                event_details.append({
                    'hospital': '',
                    'patient': pred_row['id'],
                    'file': pred_row['file_id'],
                    'fold': None,
                    'event_class': '误报',
                    'start_time': pred_row['start'].strftime('%H:%M:%S'),
                    'end_time': pred_row['end'].strftime('%H:%M:%S'),
                    'duration_seconds': pred_row['duration'],
                    'delay_seconds': np.nan
                })
        # 漏报事件
        missed = true_events[~true_events.index.isin(matched_true)]
        for idx, event in missed.iterrows():
            event_details.append({
                'hospital': '',
                'patient': event['id'],
                'file': event['file_id'],
                'fold': None,
                'event_class': '漏报',
                'start_time': event['start'].strftime('%H:%M:%S'),
                'end_time': event['end'].strftime('%H:%M:%S'),
                'duration_seconds': event['duration'],
                'delay_seconds': np.nan
            })
        fp = pred_events[~pred_events.index.isin(matched_pred)]
        if matched:
            matched_df = pd.DataFrame(matched)
            period_stats = matched_df['period'].value_counts()
            print(f"匹配事件时间段统计:")
            for period, count in period_stats.items():
                print(f"  {period}: {count} 个")
        print(f"匹配成功: {len(matched)} 个 | 误报事件: {len(fp)} 个 | 漏报事件: {len(missed)} 个")
        return pd.DataFrame(matched), fp, missed, event_details
# ----------------------
# 新增：全体人群（患者+健康合并）整体评估函数
# ----------------------
def calculate_all_metrics(all_true_events, all_pred_events, fold_num, threshold, min_length, filter_window, dur_info):
    """全部人群合并整体指标（SEN/FDR/SF/延迟+昼夜分层）"""
    print(f"\n{'=' * 30} 正在评估第{fold_num}折【全体人员合并整体】 {'=' * 30}")
    total_duration = dur_info['total_all_h']
    day_duration_hours = dur_info['day_all_h']
    night_duration_hours = dur_info['night_all_h']
    print(f"全体总时长: {total_duration:.4f}h | 白天{day_duration_hours:.4f}h | 夜晚{night_duration_hours:.4f}h")
    matched_df, fp_df, missed_df, _ = match_events(all_true_events, all_pred_events, min_length=min_length)
    # 漏检事件打印
    if not missed_df.empty:
        print(f"\n第{fold_num}折全体漏检事件详情({len(missed_df)}个):")
        for idx, event in missed_df.iterrows():
            print(f"  ID:{event['id']},时段:{event['period']},时间:{event['start'].strftime('%H:%M:%S')}~{event['end'].strftime('%H:%M:%S')},时长:{event['duration']:.1f}s")
    else:
        print(f"\n第{fold_num}折全体无漏检事件")
    # 单时段指标计算函数
    def calculate_period_metrics(true_events_period, matched_period, fp_period, period_duration_hours):
        total_true = len(true_events_period)
        total_matched = len(matched_period)
        total_fp = len(fp_period)
        SEN = total_matched / total_true if total_true > 0 else np.nan
        FDR = (total_fp / period_duration_hours) * 24 if period_duration_hours > 0 else np.nan
        SF = np.sqrt((SEN ** 2 + (1 - FDR) ** 2) / 2) if not np.isnan(SEN) and not np.isnan(FDR) else np.nan
        mean_delay = std_delay = np.nan
        if total_matched > 0:
            delays = (pd.to_datetime(matched_period['pred_start'], format='%H:%M:%S') -
                      pd.to_datetime(matched_period['true_start'], format='%H:%M:%S')).dt.total_seconds()
            mean_delay = delays.mean()
            std_delay = delays.std()
        return {
            'SEN': SEN, 'FDR': FDR, 'SF': SF,
            'mean_delay': mean_delay, 'std_delay': std_delay,
            'total_true': total_true, 'total_matched': total_matched,
            'total_fp': total_fp, 'total_missed': total_true - total_matched if total_true > 0 else 0,
            'period_duration_hours': period_duration_hours
        }
    # 整体指标
    total_true = len(all_true_events)
    total_matched = len(matched_df)
    total_fp = len(fp_df)
    total_missed = len(missed_df)
    overall_SEN = total_matched / total_true if total_true > 0 else np.nan
    overall_FDR = (total_fp / total_duration) * 24 if total_duration > 0 else np.nan
    overall_SF = np.sqrt((overall_SEN ** 2 + (1 - overall_FDR) ** 2) / 2) if not np.isnan(overall_SEN) and not np.isnan(overall_FDR) else np.nan
    overall_mean_delay = overall_std_delay = np.nan
    if total_matched > 0:
        delays = (pd.to_datetime(matched_df['pred_start'], format='%H:%M:%S') -
                  pd.to_datetime(matched_df['true_start'], format='%H:%M:%S')).dt.total_seconds()
        overall_mean_delay = delays.mean()
        overall_std_delay = delays.std()
    # 昼夜分层
    periods = ['白天', '晚上']
    period_metrics = {}
    period_durations = {'白天': day_duration_hours, '晚上': night_duration_hours}
    for period in periods:
        te_p = all_true_events[all_true_events['period'] == period]
        pe_p = all_pred_events[all_pred_events['period'] == period]
        mat_p, fp_p, _, _ = match_events(te_p, pe_p, min_length=min_length)
        period_metrics[period] = calculate_period_metrics(te_p, mat_p, fp_p, period_durations[period])
    # 打印指标
    print(f"\n全体整体指标: SEN={overall_SEN:.4f}, FDR={overall_FDR:.4f}, SF={overall_SF:.4f}, 延迟={overall_mean_delay:.1f}±{overall_std_delay:.1f}s")
    for p in periods:
        m = period_metrics[p]
        print(f"全体{p}: SEN={m['SEN']:.4f}, FDR={m['FDR']:.4f}, SF={m['SF']:.4f}, 延迟={m['mean_delay']:.1f}±{m['std_delay']:.1f}s")
    return {
        'fold': fold_num,
        'threshold': threshold,
        'min_length': min_length,
        'filter_window': filter_window,
        'overall_SEN': overall_SEN,
        'overall_FDR': overall_FDR,
        'overall_SF': overall_SF,
        'overall_mean_delay': overall_mean_delay,
        'overall_std_delay': overall_std_delay,
        'day_metrics': period_metrics['白天'],
        'night_metrics': period_metrics['晚上'],
        'all_total_h': total_duration,
        'all_day_h': day_duration_hours,
        'all_night_h': night_duration_hours,
        'total_true_events': total_true,
        'total_matched_events': total_matched,
        'total_fp_events': total_fp,
        'total_missed_events': total_missed
    }
def calculate_patient_metrics(true_events, pred_events, fold_num, threshold, min_length, filter_window, dur_info):
    """患者组完整指标（SEN/FDR/SF/延迟+昼夜分层）+ 事件明细"""
    print(f"\n{'=' * 30} 正在评估第{fold_num}折【患者组】 {'=' * 30}")
    print(f"参数：threshold={threshold}, min_length={min_length}, filter_window={filter_window}")
    total_duration = dur_info['patient_total_h']
    day_duration_hours = dur_info['patient_day_h']
    night_duration_hours = dur_info['patient_night_h']
    print(f"患者总时长: {total_duration:.4f}h | 白天{day_duration_hours:.4f}h | 夜晚{night_duration_hours:.4f}h")
    matched_df, fp_df, missed_df, event_details = match_events(true_events, pred_events, min_length=min_length)
    # 为事件明细添加折数信息
    for detail in event_details:
        detail['fold'] = fold_num
    # 漏检事件打印
    if not missed_df.empty:
        print(f"\n第{fold_num}折患者漏检事件详情({len(missed_df)}个):")
        for idx, event in missed_df.iterrows():
            print(f"  ID:{event['id']},时段:{event['period']},时间:{event['start'].strftime('%H:%M:%S')}~{event['end'].strftime('%H:%M:%S')},时长:{event['duration']:.1f}s")
    else:
        print(f"\n第{fold_num}折患者无漏检事件")
    # 单时段指标计算函数
    def calculate_period_metrics(true_events_period, matched_period, fp_period, period_duration_hours):
        total_true = len(true_events_period)
        total_matched = len(matched_period)
        total_fp = len(fp_period)
        SEN = total_matched / total_true if total_true > 0 else np.nan
        FDR = (total_fp / period_duration_hours) * 24 if period_duration_hours > 0 else np.nan
        SF = np.sqrt((SEN ** 2 + (1 - FDR) ** 2) / 2) if not np.isnan(SEN) and not np.isnan(FDR) else np.nan
        mean_delay = std_delay = np.nan
        if total_matched > 0:
            delays = (pd.to_datetime(matched_period['pred_start'], format='%H:%M:%S') -
                      pd.to_datetime(matched_period['true_start'], format='%H:%M:%S')).dt.total_seconds()
            mean_delay = delays.mean()
            std_delay = delays.std()
        return {
            'SEN': SEN, 'FDR': FDR, 'SF': SF,
            'mean_delay': mean_delay, 'std_delay': std_delay,
            'total_true': total_true, 'total_matched': total_matched,
            'total_fp': total_fp, 'total_missed': total_true - total_matched if total_true > 0 else 0,
            'period_duration_hours': period_duration_hours
        }
    # 整体指标
    total_true = len(true_events)
    total_matched = len(matched_df)
    total_fp = len(fp_df)
    total_missed = len(missed_df)
    overall_SEN = total_matched / total_true if total_true > 0 else np.nan
    overall_FDR = (total_fp / total_duration) * 24 if total_duration > 0 else np.nan
    overall_SF = np.sqrt((overall_SEN ** 2 + (1 - overall_FDR) ** 2) / 2) if not np.isnan(overall_SEN) and not np.isnan(overall_FDR) else np.nan
    overall_mean_delay = overall_std_delay = np.nan
    if total_matched > 0:
        delays = (pd.to_datetime(matched_df['pred_start'], format='%H:%M:%S') -
                  pd.to_datetime(matched_df['true_start'], format='%H:%M:%S')).dt.total_seconds()
        overall_mean_delay = delays.mean()
        overall_std_delay = delays.std()
    # 昼夜分层
    periods = ['白天', '晚上']
    period_metrics = {}
    period_durations = {'白天': day_duration_hours, '晚上': night_duration_hours}
    for period in periods:
        te_p = true_events[true_events['period'] == period]
        pe_p = pred_events[pred_events['period'] == period]
        mat_p, fp_p, _, _ = match_events(te_p, pe_p, min_length=min_length)
        period_metrics[period] = calculate_period_metrics(te_p, mat_p, fp_p, period_durations[period])
    # 打印指标
    print(f"\n患者整体指标: SEN={overall_SEN:.4f}, FDR={overall_FDR:.4f}, SF={overall_SF:.4f}, 延迟={overall_mean_delay:.1f}±{overall_std_delay:.1f}s")
    for p in periods:
        m = period_metrics[p]
        print(f"患者{p}: SEN={m['SEN']:.4f}, FDR={m['FDR']:.4f}, SF={m['SF']:.4f}, 延迟={m['mean_delay']:.1f}±{m['std_delay']:.1f}s")
    return {
        'fold': fold_num,
        'threshold': threshold,
        'min_length': min_length,
        'filter_window': filter_window,
        'overall_SEN': overall_SEN,
        'overall_FDR': overall_FDR,
        'overall_SF': overall_SF,
        'overall_mean_delay': overall_mean_delay,
        'overall_std_delay': overall_std_delay,
        'day_metrics': period_metrics['白天'],
        'night_metrics': period_metrics['晚上'],
        'patient_total_h': total_duration,
        'patient_day_h': day_duration_hours,
        'patient_night_h': night_duration_hours,
        'total_true_events': total_true,
        'total_matched_events': total_matched,
        'total_fp_events': total_fp,
        'total_missed_events': total_missed
    }, event_details
def calculate_healthy_metrics(pred_events, fold_num, threshold, min_length, filter_window, dur_info):
    """健康人仅计算误报相关指标（无真实发作，无SEN）+ 事件明细"""
    print(f"\n{'=' * 30} 正在评估第{fold_num}折【健康人组】 {'=' * 30}")
    total_duration = dur_info['healthy_total_h']
    day_duration_hours = dur_info['healthy_day_h']
    night_duration_hours = dur_info['healthy_night_h']
    print(f"健康人总时长: {total_duration:.4f}h | 白天{day_duration_hours:.4f}h | 夜晚{night_duration_hours:.4f}h")
    total_fp = len(pred_events)
    overall_FDR = (total_fp / total_duration) * 24 if total_duration > 0 else np.nan
    # 昼夜误报拆分
    pred_day = pred_events[pred_events['period'] == '白天']
    pred_night = pred_events[pred_events['period'] == '晚上']
    fp_day = len(pred_day)
    fp_night = len(pred_night)
    fdr_day = (fp_day / day_duration_hours) * 24 if day_duration_hours > 0 else np.nan
    fdr_night = (fp_night / night_duration_hours) * 24 if night_duration_hours > 0 else np.nan
    print(f"健康人整体误报事件:{total_fp}, 整体FDR={overall_FDR:.4f}/天")
    print(f"健康人白天误报:{fp_day}, FDR={fdr_day:.4f}/天 | 夜晚误报:{fp_night}, FDR={fdr_night:.4f}/天")
    # 收集健康人误报事件明细
    event_details = []
    for pred_idx, pred_row in pred_events.iterrows():
        event_details.append({
            'hospital': '',
            'patient': pred_row['id'],
            'file': pred_row['file_id'],
            'fold': fold_num,
            'event_class': '误报',
            'start_time': pred_row['start'].strftime('%H:%M:%S'),
            'end_time': pred_row['end'].strftime('%H:%M:%S'),
            'duration_seconds': pred_row['duration'],
            'delay_seconds': np.nan
        })
    return {
        'fold': fold_num,
        'threshold': threshold,
        'min_length': min_length,
        'filter_window': filter_window,
        'healthy_total_fp': total_fp,
        'healthy_overall_FDR': overall_FDR,
        'healthy_day_fp': fp_day,
        'healthy_day_FDR': fdr_day,
        'healthy_night_fp': fp_night,
        'healthy_night_FDR': fdr_night,
        'healthy_total_h': total_duration,
        'healthy_day_h': day_duration_hours,
        'healthy_night_h': night_duration_hours
    }, event_details
def evaluate_fold_combination(fold_num, threshold, min_length, filter_window, test_base_path, pred_base_path):
    """
    【核心流程重构】先全量数据提取事件，再拆分患者/健康人分组（满足先全部结果再分组要求）
    新增：拆分后先计算全体合并指标，再分别计算患者、健康人指标 + 事件明细收集
    """
    print(f"\n{'#' * 50}")
    print(f"开始评估第{fold_num}折组合: threshold={threshold}, min_length={min_length}, filter_window={filter_window}")
    # 1. 加载完整真值、预测数据（不提前拆分患者健康）
    true_df, true_patient, true_healthy, dur_info = load_validation_data_for_fold(fold_num, test_base_path)
    pred_df_all = load_prediction_data_for_fold(fold_num, pred_base_path, filter_window=filter_window)
    pred_df_all = pred_df_all.iloc[:len(true_df)]
    pred_df_all = pred_df_all.assign(
        time=true_df['time'].values,
        id=true_df['id'].values,
        file_id=true_df['file_id'].values,
        people=true_df['people'].values,
        period=true_df['period'].values
    )
    # ==================== 关键改动：先全量提取事件（所有人） ====================
    print("\n【全量数据】提取全部人员真实发作事件")
    all_true_events = extract_events(true_df, 'label', threshold=threshold, min_length=1, is_pred=False)
    print("\n【全量数据】提取全部人员预测发作事件")
    all_pred_events = extract_events(pred_df_all, 'filtered_proba', threshold=threshold, min_length=min_length,
                                     is_pred=True, true_df=true_df)
    # 从全量事件拆分：患者事件、健康人事件（后置分组）
    patient_true_events = all_true_events[all_true_events['people'] == 1].copy()
    healthy_true_events = all_true_events[all_true_events['people'] == 0].copy()
    patient_pred_events = all_pred_events[all_pred_events['people'] == 1].copy()
    healthy_pred_events = all_pred_events[all_pred_events['people'] == 0].copy()
    print(f"\n全量真实事件总数:{len(all_true_events)} | 患者真实事件:{len(patient_true_events)} | 健康人真实事件:{len(healthy_true_events)}")
    print(f"全量预测事件总数:{len(all_pred_events)} | 患者预测事件:{len(patient_pred_events)} | 健康人预测事件:{len(healthy_pred_events)}")
    # ====================== 新增：先计算全体合并指标（用户需求位置） ======================
    all_metrics = calculate_all_metrics(
        all_true_events, all_pred_events, fold_num, threshold, min_length, filter_window, dur_info
    )
    # 2. 患者分支指标计算 + 事件明细
    patient_metrics, patient_event_details = calculate_patient_metrics(
        patient_true_events, patient_pred_events, fold_num, threshold, min_length, filter_window, dur_info
    )
    # 3. 健康人分支指标计算 + 事件明细
    healthy_metrics, healthy_event_details = calculate_healthy_metrics(
        healthy_pred_events, fold_num, threshold, min_length, filter_window, dur_info
    )
    # 合并当前折的所有事件明细
    all_event_details = patient_event_details + healthy_event_details
    return all_metrics, patient_metrics, healthy_metrics, all_event_details
# ----------------------
# 新增：Excel保存函数（匹配用户提供的格式）
# ----------------------
def save_events_to_excel(event_details, save_path):
    """
    保存事件明细到Excel，格式与用户提供的一致
    列名: hospital, patient, file, fold, event_class, start_time, end_time, duration_seconds, delay_seconds
    """
    # 转换为DataFrame
    df_events = pd.DataFrame(event_details)
    # 按event_class排序：发作、误报、漏报
    class_order = {'发作': 0, '误报': 1, '漏报': 2}
    df_events['sort_order'] = df_events['event_class'].map(class_order)
    df_events = df_events.sort_values(['fold', 'sort_order', 'patient', 'start_time']).drop('sort_order', axis=1)
    # 保存到Excel
    with pd.ExcelWriter(save_path, engine='openpyxl') as writer:
        df_events.to_excel(writer, sheet_name='events', index=False)
        # 美化表格
        wb = writer.book
        ws = wb['events']
        # 表头样式
        header_fill = PatternFill('solid', fgColor='0070C0')
        header_font = Font(name='Arial', bold=True, color='FFFFFF', size=11)
        center_align = Alignment(horizontal='center', vertical='center')
        for col in range(1, ws.max_column + 1):
            cell = ws.cell(row=1, column=col)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = center_align
        # 数据行样式
        thin_gray = Side(style='thin', color='D9D9D9')
        h_border = Border(bottom=thin_gray)
        left_align = Alignment(horizontal='left', vertical='center')
        right_align = Alignment(horizontal='right', vertical='center')
        center_align_data = Alignment(horizontal='center', vertical='center')
        for row in range(2, ws.max_row + 1):
            for col in range(1, ws.max_column + 1):
                cell = ws.cell(row=row, column=col)
                cell.border = h_border
                # 对齐方式
                if col in [2, 3]:  # patient、file 左对齐
                    cell.alignment = left_align
                elif col in [7, 8, 9]:  # 时间、时长、延迟 右对齐
                    cell.alignment = right_align
                else:  # 其他居中
                    cell.alignment = center_align_data
        # 自动调整列宽
        def display_width(text):
            return sum(2 if unicodedata.east_asian_width(c) in ('F','W') else 1 for c in str(text or ''))
        for col_cells in ws.columns:
            letter = col_cells[0].column_letter
            w = max((display_width(c.value) for c in col_cells
                     if not isinstance(c, openpyxl.cell.MergedCell) and c.value is not None), default=0)
            ws.column_dimensions[letter].width = max(8, min(w * 1.1 + 3, 50))
        # 冻结表头
        ws.freeze_panes = 'A2'
    print(f"所有事件明细已保存至: {save_path}")
    return df_events
# ----------------------
# 主程序（五折交叉验证，同时保存全体+患者+健康人结果+事件明细）
# ----------------------
if __name__ == "__main__":
    # 配置路径
    TEST_BASE_PATH = r"G:\TJX\新整理的在线算法\6阶滤波\ceshiji_z(1,10)"
    PRED_BASE_PATH = (r"G:\TJX\pycharmproject\2026.8.5_new_S2model\svm\trainsvm_cv_results—6_filter")
    SAVE_ALL_CSV = os.path.join(PRED_BASE_PATH, "cv_all_metrics.csv")
    SAVE_PATIENT_CSV = os.path.join(PRED_BASE_PATH, "cv_patient_metrics.csv")
    SAVE_HEALTHY_CSV = os.path.join(PRED_BASE_PATH, "cv_healthy_metrics.csv")
    SAVE_EVENTS_EXCEL = os.path.join(PRED_BASE_PATH, "all_events_details.xlsx")  # 事件明细保存路径
    print("\n开始五折交叉验证事件评估（先全量提取事件→全体整体指标→拆分患者/健康分组评估）...")
    all_all_results = []    # 新增：全体指标结果
    all_patient_results = []
    all_healthy_results = []
    all_event_details = []  # 新增：所有事件明细
    # 遍历五折+参数网格
    for fold_num in range(1, 6):
        print(f"\n{'=' * 60}")
        print(f"===== 处理第{fold_num}折 =====")
        print(f"{'=' * 60}")
        for threshold in thresholds:
            for min_length in min_lengths:
                for filter_window in filter_windows:
                    all_res, pat_res, hea_res, event_details = evaluate_fold_combination(
                        fold_num=fold_num,
                        threshold=threshold,
                        min_length=min_length,
                        filter_window=filter_window,
                        test_base_path=TEST_BASE_PATH,
                        pred_base_path=PRED_BASE_PATH
                    )
                    all_all_results.append(all_res)
                    all_patient_results.append(pat_res)
                    all_healthy_results.append(hea_res)
                    all_event_details.extend(event_details)  # 收集所有事件明细
    # ===================== 结果保存与汇总 =====================
    # ----------------------
    # 1. 全体人员指标保存
    # ----------------------
    df_all = pd.DataFrame(all_all_results)
    df_all['day_SEN'] = df_all['day_metrics'].apply(lambda x: x['SEN'])
    df_all['day_FDR'] = df_all['day_metrics'].apply(lambda x: x['FDR'])
    df_all['day_SF'] = df_all['day_metrics'].apply(lambda x: x['SF'])
    df_all['day_mean_delay'] = df_all['day_metrics'].apply(lambda x: x['mean_delay'])
    df_all['day_std_delay'] = df_all['day_metrics'].apply(lambda x: x['std_delay'])
    df_all['night_SEN'] = df_all['night_metrics'].apply(lambda x: x['SEN'])
    df_all['night_FDR'] = df_all['night_metrics'].apply(lambda x: x['FDR'])
    df_all['night_SF'] = df_all['night_metrics'].apply(lambda x: x['SF'])
    df_all['night_mean_delay'] = df_all['night_metrics'].apply(lambda x: x['mean_delay'])
    df_all['night_std_delay'] = df_all['night_metrics'].apply(lambda x: x['std_delay'])
    df_all = df_all.drop(['day_metrics', 'night_metrics'], axis=1)
    df_all.to_csv(SAVE_ALL_CSV, index=False, encoding='utf-8-sig')
    # 2. 患者结果展开字段
    df_patient = pd.DataFrame(all_patient_results)
    df_patient['day_SEN'] = df_patient['day_metrics'].apply(lambda x: x['SEN'])
    df_patient['day_FDR'] = df_patient['day_metrics'].apply(lambda x: x['FDR'])
    df_patient['day_SF'] = df_patient['day_metrics'].apply(lambda x: x['SF'])
    df_patient['day_mean_delay'] = df_patient['day_metrics'].apply(lambda x: x['mean_delay'])
    df_patient['day_std_delay'] = df_patient['day_metrics'].apply(lambda x: x['std_delay'])
    df_patient['night_SEN'] = df_patient['night_metrics'].apply(lambda x: x['SEN'])
    df_patient['night_FDR'] = df_patient['night_metrics'].apply(lambda x: x['FDR'])
    df_patient['night_SF'] = df_patient['night_metrics'].apply(lambda x: x['SF'])
    df_patient['night_mean_delay'] = df_patient['night_metrics'].apply(lambda x: x['mean_delay'])
    df_patient['night_std_delay'] = df_patient['night_metrics'].apply(lambda x: x['std_delay'])
    df_patient = df_patient.drop(['day_metrics', 'night_metrics'], axis=1)
    df_patient.to_csv(SAVE_PATIENT_CSV, index=False, encoding='utf-8-sig')
    # 3. 健康人结果直接保存
    df_healthy = pd.DataFrame(all_healthy_results)
    df_healthy.to_csv(SAVE_HEALTHY_CSV, index=False, encoding='utf-8-sig')
    # 4. 新增：保存所有事件明细到Excel（匹配用户提供的格式）
    df_events = save_events_to_excel(all_event_details, SAVE_EVENTS_EXCEL)
    print(f"\n全体合并指标已保存至: {SAVE_ALL_CSV}")
    print(f"患者指标已保存至: {SAVE_PATIENT_CSV}")
    print(f"健康人误报指标已保存至: {SAVE_HEALTHY_CSV}")
    print(f"所有事件明细已保存至: {SAVE_EVENTS_EXCEL}")
    # 均值标准差计算工具
    def safe_mean_std(series):
        valid = series.dropna()
        if len(valid) == 0:
            return np.nan, np.nan
        return round(valid.mean(), 4), round(valid.std(), 4)
    # ----------------------
    # 新增：全体人员五折均值±标准差汇总打印
    # ----------------------
    print(f"\n{'='*60}【全体合并人群 五折交叉验证最终指标(均值±标准差)】{'='*60}")
    all_cols = [
        'overall_SEN', 'overall_FDR', 'overall_SF', 'overall_mean_delay',
        'day_SEN', 'day_FDR', 'day_SF', 'day_mean_delay',
        'night_SEN', 'night_FDR', 'night_SF', 'night_mean_delay',
        'all_total_h', 'all_day_h', 'all_night_h'
    ]
    all_summary = {}
    for col in all_cols:
        m, s = safe_mean_std(df_all[col])
        all_summary[f"{col}_mean"] = m
        all_summary[f"{col}_std"] = s
    print(f"整体 SEN: {all_summary['overall_SEN_mean']} ± {all_summary['overall_SEN_std']}")
    print(f"整体 FDR(次/天): {all_summary['overall_FDR_mean']} ± {all_summary['overall_FDR_std']}")
    print(f"整体 SF: {all_summary['overall_SF_mean']} ± {all_summary['overall_SF_std']}")
    print(f"整体预警延迟(s): {all_summary['overall_mean_delay_mean']:.1f} ± {all_summary['overall_mean_delay_std']:.1f}")
    print("-"*40)
    print(f"白天 SEN: {all_summary['day_SEN_mean']} ± {all_summary['day_SEN_std']}")
    print(f"白天 FDR: {all_summary['day_FDR_mean']} ± {all_summary['day_FDR_std']}")
    print(f"白天 SF: {all_summary['day_SF_mean']} ± {all_summary['day_SF_std']}")
    print(f"白天预警延迟(s): {all_summary['day_mean_delay_mean']:.1f} ± {all_summary['day_mean_delay_std']:.1f}")
    print("-"*40)
    print(f"夜晚 SEN: {all_summary['night_SEN_mean']} ± {all_summary['night_SEN_std']}")
    print(f"夜晚 FDR: {all_summary['night_FDR_mean']} ± {all_summary['night_FDR_std']}")
    print(f"夜晚 SF: {all_summary['night_SF_mean']} ± {all_summary['night_SF_std']}")
    print(f"夜晚预警延迟(s): {all_summary['night_mean_delay_mean']:.1f} ± {all_summary['night_mean_delay_std']:.1f}")
    print("-"*40)
    print(f"全体平均总时长(h): {all_summary['all_total_h_mean']:.4f} | 白天{all_summary['all_day_h_mean']:.4f}h | 夜晚{all_summary['all_night_h_mean']:.4f}h")
    # ----------------------
    # 患者五折均值±标准差
    # ----------------------
    print(f"\n{'='*60}【患者组 五折交叉验证最终指标(均值±标准差)】{'='*60}")
    pat_cols = [
        'overall_SEN', 'overall_FDR', 'overall_SF', 'overall_mean_delay',
        'day_SEN', 'day_FDR', 'day_SF', 'day_mean_delay',
        'night_SEN', 'night_FDR', 'night_SF', 'night_mean_delay',
        'patient_total_h', 'patient_day_h', 'patient_night_h'
    ]
    pat_summary = {}
    for col in pat_cols:
        m, s = safe_mean_std(df_patient[col])
        pat_summary[f"{col}_mean"] = m
        pat_summary[f"{col}_std"] = s
    print(f"整体 SEN: {pat_summary['overall_SEN_mean']} ± {pat_summary['overall_SEN_std']}")
    print(f"整体 FDR(次/天): {pat_summary['overall_FDR_mean']} ± {pat_summary['overall_FDR_std']}")
    print(f"整体 SF: {pat_summary['overall_SF_mean']} ± {pat_summary['overall_SF_std']}")
    print(f"整体预警延迟(s): {pat_summary['overall_mean_delay_mean']:.1f} ± {pat_summary['overall_mean_delay_std']:.1f}")
    print("-"*40)
    print(f"白天 SEN: {pat_summary['day_SEN_mean']} ± {pat_summary['day_SEN_std']}")
    print(f"白天 FDR: {pat_summary['day_FDR_mean']} ± {pat_summary['day_FDR_std']}")
    print(f"白天 SF: {pat_summary['day_SF_mean']} ± {pat_summary['day_SF_std']}")
    print(f"白天预警延迟(s): {pat_summary['day_mean_delay_mean']:.1f} ± {pat_summary['day_mean_delay_std']:.1f}")
    print("-"*40)
    print(f"夜晚 SEN: {pat_summary['night_SEN_mean']} ± {pat_summary['night_SEN_std']}")
    print(f"夜晚 FDR: {pat_summary['night_FDR_mean']} ± {pat_summary['night_FDR_std']}")
    print(f"夜晚 SF: {pat_summary['night_SF_mean']} ± {pat_summary['night_SF_std']}")
    print(f"夜晚预警延迟(s): {pat_summary['night_mean_delay_mean']:.1f} ± {pat_summary['night_mean_delay_std']:.1f}")
    print("-"*40)
    print(f"患者平均总时长(h): {pat_summary['patient_total_h_mean']:.4f} | 白天{pat_summary['patient_day_h_mean']:.4f}h | 夜晚{pat_summary['patient_night_h_mean']:.4f}h")
    # ----------------------
    # 健康人五折均值±标准差（仅误报FDR）
    # ----------------------
    print(f"\n{'='*60}【健康人组 五折误报指标(均值±标准差)】{'='*60}")
    hea_cols = [
        'healthy_overall_FDR', 'healthy_total_fp',
        'healthy_day_FDR', 'healthy_day_fp',
        'healthy_night_FDR', 'healthy_night_fp',
        'healthy_total_h', 'healthy_day_h', 'healthy_night_h'
    ]
    hea_summary = {}
    for col in hea_cols:
        m, s = safe_mean_std(df_healthy[col])
        hea_summary[f"{col}_mean"] = m
        hea_summary[f"{col}_std"] = s
    print(f"健康人整体误报数量: {hea_summary['healthy_total_fp_mean']:.2f} ± {hea_summary['healthy_total_fp_std']:.2f}")
    print(f"健康人整体FDR(次/天): {hea_summary['healthy_overall_FDR_mean']:.4f} ± {hea_summary['healthy_overall_FDR_std']:.4f}")
    print("-"*30)
    print(f"白天误报数: {hea_summary['healthy_day_fp_mean']:.2f} ± {hea_summary['healthy_day_fp_std']:.2f}")
    print(f"白天FDR: {hea_summary['healthy_day_FDR_mean']:.4f} ± {hea_summary['healthy_day_FDR_std']:.4f}")
    print("-"*30)
    print(f"夜晚误报数: {hea_summary['healthy_night_fp_mean']:.2f} ± {hea_summary['healthy_night_fp_std']:.2f}")
    print(f"夜晚FDR: {hea_summary['healthy_night_FDR_mean']:.4f} ± {hea_summary['healthy_night_FDR_std']:.4f}")
    print("-"*30)
    print(f"健康人平均总时长(h): {hea_summary['healthy_total_h_mean']:.4f} | 白天{hea_summary['healthy_day_h_mean']:.4f}h | 夜晚{hea_summary['healthy_night_h_mean']:.4f}h")
    # ----------------------
    # 全局总事件汇总
    # ----------------------
    print(f"\n{'='*60}【全局事件总览（五折合计）】{'='*60}")
    total_all_true_events = df_all['total_true_events'].sum()
    total_all_fp = df_all['total_fp_events'].sum()
    total_patient_true_events = df_patient['total_true_events'].sum()
    total_patient_pred_fp = df_patient['total_fp_events'].sum()
    total_healthy_pred_fp = df_healthy['healthy_total_fp'].sum()
    print(f"全体合并真实发作总事件数：{total_all_true_events}")
    print(f"全体合并预测误报总事件数：{total_all_fp}")
    print(f"患者真实发作总事件数：{total_patient_true_events}")
    print(f"患者预测误报总事件数：{total_patient_pred_fp}")
    print(f"健康人全部误报总事件数：{total_healthy_pred_fp}")
    print(f"模型全部误报事件（患者+健康人）：{total_patient_pred_fp + total_healthy_pred_fp}")
    # ----------------------
    # 事件明细汇总打印
    # ----------------------
    print(f"\n{'='*60}【事件明细汇总】{'='*60}")
    event_class_stats = df_events['event_class'].value_counts()
    print(f"发作事件总数: {event_class_stats.get('发作', 0)}")
    print(f"误报事件总数: {event_class_stats.get('误报', 0)}")
    print(f"漏报事件总数: {event_class_stats.get('漏报', 0)}")
    print(f"\n{'='*60}【健康人组 五折误报指标(均值±标准差)】{'='*60}")
    hea_cols = [
        'healthy_overall_FDR', 'healthy_total_fp',
        'healthy_day_FDR', 'healthy_day_fp',
        'healthy_night_FDR', 'healthy_night_fp',
        'healthy_total_h', 'healthy_day_h', 'healthy_night_h'
    ]
    hea_summary = {}
    for col in hea_cols:
        m, s = safe_mean_std(df_healthy[col])
        hea_summary[f"{col}_mean"] = m
        hea_summary[f"{col}_std"] = s
    print(f"健康人整体误报数量: {hea_summary['healthy_total_fp_mean']:.2f} ± {hea_summary['healthy_total_fp_std']:.2f}")
    print(f"健康人整体FDR(次/天): {hea_summary['healthy_overall_FDR_mean']:.4f} ± {hea_summary['healthy_overall_FDR_std']:.4f}")
    print("-"*30)
    print(f"白天误报数: {hea_summary['healthy_day_fp_mean']:.2f} ± {hea_summary['healthy_day_fp_std']:.2f}")
    print(f"白天FDR: {hea_summary['healthy_day_FDR_mean']:.4f} ± {hea_summary['healthy_day_FDR_std']:.4f}")
    print("-"*30)
    print(f"夜晚误报数: {hea_summary['healthy_night_fp_mean']:.2f} ± {hea_summary['healthy_night_fp_std']:.2f}")
    print(f"夜晚FDR: {hea_summary['healthy_night_FDR_mean']:.4f} ± {hea_summary['healthy_night_FDR_std']:.4f}")
    print("-"*30)
    print(f"健康人平均总时长(h): {hea_summary['healthy_total_h_mean']:.4f} | 白天{hea_summary['healthy_day_h_mean']:.4f}h | 夜晚{hea_summary['healthy_night_h_mean']:.4f}h")
    # ----------------------
    # 全局总事件汇总
    # ----------------------
    print(f"\n{'='*60}【全局事件总览（五折合计）】{'='*60}")
    total_all_true_events = df_all['total_true_events'].sum()
    total_all_fp = df_all['total_fp_events'].sum()
    total_patient_true_events = df_patient['total_true_events'].sum()
    total_patient_pred_fp = df_patient['total_fp_events'].sum()
    total_healthy_pred_fp = df_healthy['healthy_total_fp'].sum()
    print(f"全体合并真实发作总事件数：{total_all_true_events}")
    print(f"全体合并预测误报总事件数：{total_all_fp}")
    print(f"患者真实发作总事件数：{total_patient_true_events}")
    print(f"患者预测误报总事件数：{total_patient_pred_fp}")
    print(f"健康人全部误报总事件数：{total_healthy_pred_fp}")
    print(f"模型全部误报事件（患者+健康人）：{total_patient_pred_fp + total_healthy_pred_fp}")
    # ----------------------
    # 事件明细汇总打印
    # ----------------------
    print(f"\n{'='*60}【事件明细汇总】{'='*60}")
    event_class_stats = df_events['event_class'].value_counts()
    print(f"发作事件总数: {event_class_stats.get('发作', 0)}")
    print(f"误报事件总数: {event_class_stats.get('误报', 0)}")
    print(f"漏报事件总数: {event_class_stats.get('漏报', 0)}")
    print("事件明细已按折数、事件类型、患者、时间排序保存到Excel")

