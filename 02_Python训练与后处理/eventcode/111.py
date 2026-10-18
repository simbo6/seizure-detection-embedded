import pandas as pd
import h5py
import numpy as np
import os

filter_window = 4
print(f"初始化完成: 均值滤波窗口大小={filter_window},仅处理第5折")

def forward_mean_filter(data, k=6):
    if len(data) < k:
        print(f"警告：数据长度({len(data)})小于滤波窗口大小({k})，返回原数据")
        return data.copy()
    filtered_data = data.copy()
    for t in range(k - 1, len(data)):
        window = data[t - k + 1: t + 1]
        filtered_data[t] = np.mean(window)
    return filtered_data

def load_true_data(base_path, fold_num):
    print(f"\n读取第{fold_num}折真实数据...")
    fold_test_path = os.path.join(base_path, f"{fold_num}cross")
    test_file = os.path.join(fold_test_path, "combined_features_lab_z.mat")
    with h5py.File(test_file, 'r') as f:
        dataset = f['test_all_lab_raw'][()].T
        data = dataset[:, [0, 1, 2, 3, 6]]
    true_df = pd.DataFrame(data, columns=['label', 'id', 'people', 'time', 'file_id'])
    int_columns = ['id', 'file_id', 'people', 'label']
    true_df[int_columns] = true_df[int_columns].astype(np.int64)
    true_df['time'] = true_df['time'].astype(np.float64).astype(np.int64)
    time_str = true_df['time'].astype(str).str.zfill(6)
    true_df['time'] = pd.to_datetime(time_str, format='%H%M%S', errors='coerce')
    true_df = true_df.dropna(subset=['time'])
    print(f"真实数据有效行数: {len(true_df)}")
    return true_df

def load_pred_data(pred_base_path, fold_num, filter_window):
    print(f"\n读取第{fold_num}折预测数据...")
    fold_pred_path = os.path.join(pred_base_path, f"fold_{fold_num}")
    pred_file = os.path.join(fold_pred_path, f"fold_{fold_num}_predictions.csv")
    pred_df = pd.read_csv(pred_file)
    pred_df['raw_proba'] = pred_df['filtered_proba'].copy()
    pred_df['filtered_proba'] = forward_mean_filter(pred_df['filtered_proba'].values, k=filter_window)
    print(f"预测数据行数: {len(pred_df)}")
    return pred_df

def save_onset_prediction(true_df, pred_df, save_path):
    print("\n筛选真实发作label=1的数据并保存...")
    pred_df = pred_df.iloc[:len(true_df)]
    merged_df = pred_df.assign(
        label=true_df['label'].values,
        time=true_df['time'].values,
        id=true_df['id'].values,
        file_id=true_df['file_id'].values,
        people=true_df['people'].values
    )
    onset_df = merged_df[merged_df['label'] == 1].copy()
    result_df = onset_df[['id', 'file_id', 'people', 'time', 'label', 'raw_proba', 'filtered_proba']]
    result_df.to_csv(save_path, index=False, encoding='utf-8-sig')
    print(f"真实发作样本共{len(result_df)}行，保存至: {save_path}")
    return result_df

if __name__ == "__main__":
    TEST_BASE_PATH = r"G:\TJX\新整理的在线算法\ceshiji_z{1,10}"
    PRED_BASE_PATH = r"G:\TJX\pycharmproject\2026.8.5_new_S2model\trainsvm_cv_results—25"
    SAVE_CSV = os.path.join(PRED_BASE_PATH, "fold5_onset_prediction_values.csv")
    fold_num = 5

    true_df = load_true_data(TEST_BASE_PATH, fold_num)
    pred_df = load_pred_data(PRED_BASE_PATH, fold_num, filter_window)
    onset_result = save_onset_prediction(true_df, pred_df, SAVE_CSV)

    print("\n结果预览前10行：")
    print(onset_result.head(200))