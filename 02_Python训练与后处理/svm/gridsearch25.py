import pandas as pd
import h5py
import numpy as np
from datetime import datetime, timedelta
import os
# ----------------------
# 基础配置（按需求调整）
# ----------------------
merge_interval = 300  # 秒，事件合并阈值
print(f"初始化完成: 事件合并阈值={merge_interval}秒")
# 超参数网格搜索（C参数放到最开头，按需求最后搜索+五折聚合）
c_values = [0.0625,0.125,0.25,0.5,1,2,4,8,16,32,64,128,256,512,1024]  # SVM惩罚系数网格，可自行修改
thresholds = [0.5,0.55,0.6,0.65,0.7,0.75,0.8]
min_lengths = [3,4,5,6]
filter_windows = [2,3,4]  # 均值滤波窗口大小超参数
print(
    f"超参数网格: C={c_values}, thresholds={thresholds}, min_lengths={min_lengths}, filter_windows={filter_windows}\n")
# ----------------------
# 核心工具函数
# ----------------------
def forward_mean_filter(data, k=6):
    """前向均值滤波函数"""
    if len(data) < k:
        print(f"警告：数据长度({len(data)})小于滤波窗口大小({k})，返回原数据")
        return data.copy()
    filtered_data = data.copy()
    for t in range(k - 1, len(data)):
        window = data[t - k + 1: t + 1]
        filtered_data[t] = np.mean(window)
    return filtered_data
def load_validation_data_for_fold(fold_num, base_path):
    """加载指定折的真值数据（五折交叉验证，只读1次/折）"""
    print(f"\n[步骤1/3] 读取第{fold_num}折真值数据...")
    fold_test_path = os.path.join(base_path, f"{fold_num}cross")
    test_file = os.path.join(fold_test_path, "combined_features_lab_z.mat")
    print(f"真值数据路径: {test_file}")
    with h5py.File(test_file, 'r') as f:
        dataset = f['test_all_lab_raw'][()].T
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
    # 整体时长统计
    total_samples = len(true_df)
    total_duration_hours = total_samples * 2 / 3600
    print(f"第{fold_num}折有效行数: {len(true_df)}, 总时长{total_duration_hours:.4f}h")
    dur_info = {
        "total_all_h": total_duration_hours
    }
    return true_df, dur_info
def load_prediction_data_for_fold(fold_num, pred_base_path):
    """加载指定折的预测数据（只读1次/C/折，避免重复IO）"""
    print(f"\n[步骤2/3] 读取第{fold_num}折预测数据...")
    fold_pred_path = os.path.join(pred_base_path, f"fold_{fold_num}")
    pred_file = os.path.join(fold_pred_path, f"fold_{fold_num}_predictions.csv")
    print(f"预测数据路径: {pred_file}")
    pred_df = pd.read_csv(pred_file)
    print(f"第{fold_num}折预测数据加载完成，行数: {len(pred_df)}")
    return pred_df
def extract_events(df, value_column, threshold=0.5, min_length=6, is_pred=False, true_df=None):
    """事件提取函数（修复索引越界问题，仅保留整体事件逻辑）"""
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
            # 预测事件过滤无效样本
            if is_pred:
                if len(event_group) > len(true_df):
                    event_group = event_group.iloc[:len(true_df)]
                indices = event_group.index
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
            # 事件起止、时长
            start_time = event_group['time'].min()
            end_time = event_group['time'].max()
            all_events.append({
                'id': event_group['id'].iloc[0],
                'start': start_time,
                'end': end_time,
                'file_id': file_id,
                'duration': (end_time - start_time).total_seconds()
            })
    # 合并邻近事件
    if all_events:
        events_df = pd.DataFrame(all_events)
        events_df = events_df.sort_values(['id', 'file_id', 'start'])
        merged_events = []
        for (id_val, file_id_val), group in events_df.groupby(['id', 'file_id']):
            if group.empty:
                continue
            merged = [group.iloc[0].to_dict()]
            for _, row in group.iloc[1:].iterrows():
                last_event = merged[-1]
                time_diff = (row['start'] - last_event['end']).total_seconds()
                if time_diff <= merge_interval:
                    last_event['end'] = row['end']
                    last_event['duration'] = (last_event['end'] - last_event['start']).total_seconds()
                else:
                    merged.append(row.to_dict())
            merged_events.extend(merged)
        all_events = merged_events
    return pd.DataFrame(all_events)
def match_events(true_events, pred_events):
    """事件匹配函数"""
    if true_events.empty:
        matched = pd.DataFrame()
        fp = pred_events
        missed = true_events
        return matched, fp, missed
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
            if not candidates.empty:
                true_match = candidates.iloc[0]
                matched.append({
                    'pred_id': pred_idx,
                    'pred_start': pred_row['start'].strftime('%H:%M:%S'),
                    'pred_end': pred_row['end'].strftime('%H:%M:%S'),
                    'true_start': true_match['start'].strftime('%H:%M:%S'),
                    'true_end': true_match['end'].strftime('%H:%M:%S'),
                    'id': pred_row['id'],
                    'file_id': pred_row['file_id'],
                    'duration': pred_row['duration']
                })
                matched_true.add(true_match.name)
                matched_pred.add(pred_idx)
        fp = pred_events[~pred_events.index.isin(matched_pred)]
        missed = true_events[~true_events.index.isin(matched_true)]
        return pd.DataFrame(matched), fp, missed
def calculate_overall_metrics(true_events, pred_events, fold_num, threshold, min_length, filter_window, dur_info):
    """计算整体指标（仅保留全体整体结果，无分层）"""
    total_duration = dur_info['total_all_h']
    matched_df, fp_df, missed_df = match_events(true_events, pred_events)
    # 整体指标计算
    total_true = len(true_events)
    total_matched = len(matched_df)
    total_fp = len(fp_df)
    total_missed = len(missed_df)
    SEN = total_matched / total_true if total_true > 0 else np.nan
    FDR = (total_fp / total_duration) * 24 if total_duration > 0 else np.nan
    SF = np.sqrt((SEN ** 2 + (1 - FDR) ** 2) / 2) if not np.isnan(SEN) and not np.isnan(FDR) else np.nan
    mean_delay = std_delay = np.nan
    if total_matched > 0:
        delays = (pd.to_datetime(matched_df['pred_start'], format='%H:%M:%S') -
                  pd.to_datetime(matched_df['true_start'], format='%H:%M:%S')).dt.total_seconds()
        mean_delay = delays.mean() + (min_length - 1) * 2
        std_delay = delays.std()
    return {
        'fold': fold_num,
        'C': C,
        'threshold': threshold,
        'min_length': min_length,
        'filter_window': filter_window,
        'SEN': SEN,
        'FDR': FDR,
        'SF': SF,
        'mean_delay': mean_delay,
        'std_delay': std_delay,
        'total_true': total_true,
        'total_matched': total_matched,
        'total_fp': total_fp,
        'total_missed': total_missed,
        'total_duration_h': total_duration
    }
# ----------------------
# 主程序（五折+最后搜索C+单C单文件输出）
# ----------------------
if __name__ == "__main__":
    # 配置路径
    TEST_BASE_PATH = r"G:\TJX\新整理的在线算法\ceshiji_z{1,10}"
    PRED_BASE_ROOT = r"G:\TJX\pycharmproject\2026.8.5_new_S2model\gridsearch25"  # 预测根路径，自动拼接C文件夹
    print("\n开始五折交叉验证事件评估（最后搜索C+五折聚合输出）...")
    all_results = []  # 存储所有折所有C所有超参组合的结果
    # 1. 外层循环：五折交叉验证
    for fold_num in range(1, 6):
        print(f"\n{'=' * 60}")
        print(f"===== 处理第{fold_num}折 =====")
        print(f"{'=' * 60}")
        # 读取该折真值数据（只读1次/折）
        true_df, dur_info = load_validation_data_for_fold(fold_num, TEST_BASE_PATH)
        # 2. 中层循环：最后搜索C参数（按需求调整顺序）
        for C in c_values:
            print(f"\n--- 处理C={C} ---")
            # 拼接该C的预测文件夹路径
            pred_base_path = os.path.join(PRED_BASE_ROOT, f"trainsvm_cv_25feat_C{C}")
            # 读取该C该折的预测数据（只读1次/C/折）
            pred_df_base = load_prediction_data_for_fold(fold_num, pred_base_path)
            # 对齐真值数据长度，补充必要列
            pred_df_base = pred_df_base.iloc[:len(true_df)]
            pred_df_base = pred_df_base.assign(
                time=true_df['time'].values,
                id=true_df['id'].values,
                file_id=true_df['file_id'].values
            )
            # 3. 内层循环：超参数网格搜索
            for filter_window in filter_windows:
                # 对当前滤波窗口生成滤波后的概率列（避免重复读文件）
                pred_df_base['current_filtered_proba'] = forward_mean_filter(
                    pred_df_base['filtered_proba'].values, k=filter_window
                )
                print(f"已生成滤波窗口={filter_window}的预测概率")
                for threshold in thresholds:
                    for min_length in min_lengths:
                        print(
                            f"\n评估组合: C={C}, threshold={threshold}, min_length={min_length}, filter_window={filter_window}")
                        # 提取真实事件（min_length=1，完整提取）
                        all_true_events = extract_events(
                            true_df, 'label', threshold=threshold, min_length=1, is_pred=False
                        )
                        # 提取预测事件
                        all_pred_events = extract_events(
                            pred_df_base, 'current_filtered_proba', threshold=threshold,
                            min_length=min_length, is_pred=True, true_df=true_df
                        )
                        # 计算整体指标
                        metrics = calculate_overall_metrics(
                            all_true_events, all_pred_events, fold_num,
                            threshold, min_length, filter_window, dur_info
                        )
                        all_results.append(metrics)
    # ----------------------
    # 结果聚合与输出（按C分组，五折聚合）
    # ----------------------
    # 转换为DataFrame
    df_all = pd.DataFrame(all_results)
    # 均值标准差计算工具
    def safe_mean_std(series):
        valid = series.dropna()
        if len(valid) == 0:
            return np.nan, np.nan
        return round(valid.mean(), 4), round(valid.std(), 4)
    # 按C分组，生成每个C的五折聚合结果
    for C in c_values:
        print(f"\n{'=' * 60}【C={C} 五折聚合结果】{'=' * 60}")
        # 筛选当前C的所有结果
        df_c = df_all[df_all['C'] == C].copy()
        # 按超参数组合分组，聚合五折结果
        agg_results = []
        for (threshold, min_length, filter_window), group in df_c.groupby(['threshold', 'min_length', 'filter_window']):
            # 计算均值±标准差
            sen_mean, sen_std = safe_mean_std(group['SEN'])
            fdr_mean, fdr_std = safe_mean_std(group['FDR'])
            sf_mean, sf_std = safe_mean_std(group['SF'])
            delay_mean, delay_std = safe_mean_std(group['mean_delay'])
            # 累加五折事件总数
            total_true_sum = group['total_true'].sum()
            total_matched_sum = group['total_matched'].sum()
            total_fp_sum = group['total_fp'].sum()
            total_missed_sum = group['total_missed'].sum()
            # 平均总时长
            avg_total_h = group['total_duration_h'].mean()
            agg_results.append({
                'C': C,
                'threshold': threshold,
                'min_length': min_length,
                'filter_window': filter_window,
                'SEN_mean': sen_mean,
                'SEN_std': sen_std,
                'FDR_mean': fdr_mean,
                'FDR_std': fdr_std,
                'SF_mean': sf_mean,
                'SF_std': sf_std,
                'delay_mean': delay_mean,
                'delay_std': delay_std,
                'total_true_sum': total_true_sum,
                'total_matched_sum': total_matched_sum,
                'total_fp_sum': total_fp_sum,
                'total_missed_sum': total_missed_sum,
                'avg_total_h': round(avg_total_h, 4)
            })
        # 转换为DataFrame
        df_agg = pd.DataFrame(agg_results)
        # 保存到对应C的文件夹
        save_path = os.path.join(PRED_BASE_ROOT, f"trainsvm_cv_results_71_c={C}", f"cv_overall_summary_C{C}.xlsx")
        # 自动创建输出文件夹
        save_dir = os.path.dirname(save_path)
        os.makedirs(save_dir, exist_ok=True)
        # 移除encoding参数，修复报错
        df_agg.to_excel(save_path, index=False)
        print(f"C={C} 的五折聚合结果已保存至: {save_path}")

    # ----------------------
    # 全局总事件汇总
    # ----------------------
    print(f"\n{'=' * 60}【全局事件总览（五折合计）】{'=' * 60}")
    total_all_true_events = df_all['total_true'].sum()
    total_all_fp = df_all['total_fp'].sum()
    total_all_matched = df_all['total_matched'].sum()
    total_all_missed = df_all['total_missed'].sum()
    print(f"五折全局真实发作总事件数：{total_all_true_events}")
    print(f"五折全局匹配成功总事件数：{total_all_matched}")
    print(f"五折全局误报总事件数：{total_all_fp}")
    print(f"五折全局漏报总事件数：{total_all_missed}")

    # ====================== 新增：自动找出全局最优超参（SF最高） ======================
    print("\n" + "="*70)
    print("【全局最优超参组合（全部C+全部超参，按SF_mean排序）】")
    print("="*70)
    # 把所有C的聚合结果合并成一张总表
    all_agg_list = []
    for C in c_values:
        save_path = os.path.join(PRED_BASE_ROOT, f"trainsvm_cv_results_71_c={C}", f"cv_overall_summary_C{C}.xlsx")
        if os.path.exists(save_path):
            df_temp = pd.read_excel(save_path)
            all_agg_list.append(df_temp)
    if len(all_agg_list) > 0:
        df_all_agg = pd.concat(all_agg_list, ignore_index=True)
        # 按SF_mean降序排序，取第一名
        df_sorted = df_all_agg.sort_values("SF_mean", ascending=False).reset_index(drop=True)
        best = df_sorted.iloc[0]
        print(f"最优参数：")
        print(f"C = {best['C']}")
        print(f"threshold = {best['threshold']}")
        print(f"min_length = {best['min_length']}")
        print(f"filter_window = {best['filter_window']}")
        print(f"SEN_mean = {best['SEN_mean']} ± {best['SEN_std']}")
        print(f"FDR_mean = {best['FDR_mean']} ± {best['FDR_std']}")
        print(f"SF_mean = {best['SF_mean']}")
        print(f"预警延迟mean = {best['delay_mean']} ± {best['delay_std']}")
        # 保存全局汇总表
        global_save = os.path.join(PRED_BASE_ROOT, "cv_global_all_summary.xlsx")
        df_all_agg.to_excel(global_save, index=False)
        print(f"\n全部超参汇总表已保存到：{global_save}")
    else:
        print("没有读取到聚合结果文件")
