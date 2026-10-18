import numpy as np
import os
import h5py
from sklearn.svm import LinearSVC
from sklearn.model_selection import train_test_split
from sklearn.metrics import f1_score, accuracy_score, precision_score, recall_score, classification_report
import joblib
import pandas as pd
import time

def sigmoid(x):
    return 1 / (1 + np.exp(-x))

def my_folder(path):
    if not os.path.exists(path):
        os.makedirs(path)
    return path

def load_training_data_v73(train_folder, fold_num, selected_features_idx, save_path):
    fold_train_path = os.path.join(train_folder, f"{fold_num}cross")
    features_file = os.path.join(fold_train_path, "combined_features_z.mat")
    lab_file = os.path.join(fold_train_path, "combined_lab_z.mat")
    with h5py.File(features_file, 'r') as f:
        X = f['all_features'][()].T
        X = X[:, selected_features_idx]
    with h5py.File(lab_file, 'r') as f:
        lab = f['train_all_lab_raw'][()].T
        y = lab[:, 0].astype(np.int8)
        fifth_col = lab[:, 4].astype(np.int8)
    seizure_mask = (y == 1)
    X_seizure = X[seizure_mask]
    y_seizure = y[seizure_mask]
    fifth_col_seizure = fifth_col[seizure_mask]
    X_non_seizure = X[~seizure_mask]
    y_non_seizure = y[~seizure_mask]
    fifth_col_non_seizure = fifth_col[~seizure_mask]
    X_non_seizure_sampled = X_non_seizure[::3]
    y_non_seizure_sampled = y_non_seizure[::3]
    fifth_col_non_seizure_sampled = fifth_col_non_seizure[::3]
    X_combined = np.vstack((X_seizure, X_non_seizure_sampled))
    y_combined = np.concatenate((y_seizure, y_non_seizure_sampled))
    fifth_col_combined = np.concatenate((fifth_col_seizure, fifth_col_non_seizure_sampled))
    mask_fifth = (fifth_col_combined == 1)
    X_filtered = X_combined[mask_fifth]
    y_filtered = y_combined[mask_fifth]
    if len(X_filtered) == 0:
        raise ValueError(f"第{fold_num}折训练集筛选第五列标签为1后样本为空，请检查数据或降采样逻辑")
    print(f"\n第{fold_num}折训练集加载完成")
    print(f"原始样本数: {len(y)}")
    print(f"降采样后非发作样本数: {len(y_non_seizure_sampled)}")
    print(f"发作样本数: {len(y_seizure)}")
    print(f"合并样本数: {len(y_combined)}")
    print(f"第五列标签为1的样本数: {len(y_filtered)}")
    print(f"特征矩阵形状: {X_filtered.shape} (选择了{len(selected_features_idx)}个特征)")
    print(f"标签分布: {dict(zip(*np.unique(y_filtered, return_counts=True)))}")
    return X_filtered, y_filtered

def load_test_data_v73(test_folder, fold_num, selected_features_idx):
    fold_test_path = os.path.join(test_folder, f"{fold_num}cross")
    test_file = os.path.join(fold_test_path, "combined_features_lab_z.mat")
    with h5py.File(test_file, 'r') as f:
        X = f['all_features'][()].T
        X = X[:, selected_features_idx]
        lab = f['test_all_lab_raw'][()].T
        y = lab[:, 0].astype(np.int8)
        fifth_col = lab[:, 4].astype(np.int8)
        sixth_col = lab[:, 5].astype(np.int8)
    mask = (fifth_col == 1)
    X_filtered = X[mask]
    y_filtered = y[mask]
    if len(X_filtered) == 0:
        print(f"警告：第{fold_num}折测试集中没有第五列标签为1的样本，预测结果全为0")
        return None, None, mask, sixth_col, y
    print(f"\n第{fold_num}折测试集加载完成")
    print(f"原始样本数: {len(y)}，筛选后（第五列标签为1）: {len(y_filtered)}")
    print(f"特征矩阵形状: {X_filtered.shape} (选择了{len(selected_features_idx)}个特征)")
    print(f"标签分布: {dict(zip(*np.unique(y_filtered, return_counts=True)))}")
    return X_filtered, y_filtered, mask, sixth_col, y

def preprocess_data(X, scaler=None):
    print(f"跳过额外预处理，数据形状: {X.shape}")
    return X, None

def load_fold_features(feature_root, fold_num, feature_count):
    csv_path = os.path.join(
        feature_root, "xunlianji_featurecife{1,10}", f"{fold_num}cross",
        "all_k_selected_features.csv"
    )
    if not os.path.isfile(csv_path):
        raise FileNotFoundError(f"Missing feature‑selection result: {csv_path}")
    table = pd.read_csv(csv_path)
    rows = table.loc[table["K"].astype(int) == int(feature_count)]
    if rows.empty:
        raise ValueError(f"K={feature_count} not found in {csv_path}")
    row = rows.iloc[0]
    feature_columns = [c for c in table.columns if c.startswith("FeatureIndex_")]
    indices = [int(row[c]) - 1 for c in feature_columns if pd.notna(row[c])]
    if len(indices) != int(feature_count):
        raise ValueError(
            f"Expected {feature_count} features for fold {fold_num}, "
            f"found {len(indices)} in {csv_path}"
        )
    if len(set(indices)) != len(indices) or any(i < 0 or i >= 71 for i in indices):
        raise ValueError(f"Invalid feature indices for K={feature_count}: {indices}")
    return indices

def linear_interpolation(data, mask):
    interpolated_data = data.copy()
    indices = np.arange(len(data))
    valid_mask = ~mask
    if np.sum(valid_mask) < 2:
        print("警告：有效数据点不足，无法进行线性插值，返回原数据")
        return interpolated_data
    interpolated_data[mask] = np.interp(
        indices[mask],
        indices[valid_mask],
        data[valid_mask]
    )
    return interpolated_data

def full_pipeline(train_folder, test_folder, fold_num, selected_features_idx, save_base_path, c_value=64, runs=1):
    save_path = my_folder(os.path.join(save_base_path, f"fold_{fold_num}"))
    print("\n" + "=" * 40)
    print(f"第{fold_num}折 - 加载并处理训练数据...")
    X_train, y_train = load_training_data_v73(train_folder, fold_num, selected_features_idx, save_path)
    print("\n进行数据预处理...")
    X_train_scaled, _ = preprocess_data(X_train)
    print("\n划分训练验证集...")
    if len(X_train_scaled) < 5:
        print("警告：训练样本数量过少（{}个），跳过验证集划分，直接使用所有样本训练".format(len(X_train_scaled)))
        X_train_split, y_train_split = X_train_scaled, y_train
        X_val, y_val = None, None
    else:
        X_train_split, X_val, y_train_split, y_val = train_test_split(
            X_train_scaled, y_train,
            test_size=0.1,
            random_state=42,
            stratify=y_train
        )
    print("\n" + "=" * 40)
    print(f"第{fold_num}折 - 开始模型训练...")
    best_model = None
    best_f1 = -1
    for run in range(1, runs + 1):
        start = time.time()
        print(f"\nRun {run}/{runs}")
        base_model = LinearSVC(
            C=c_value,
            class_weight='balanced',
            max_iter=2000,
            random_state=42 + run,
            dual=False
        )
        base_model.fit(X_train_split, y_train_split)
        print(f"训练集样本数: {len(y_train_split)}, 标签分布: {dict(zip(*np.unique(y_train_split, return_counts=True)))}")
        base_model_path = os.path.join(save_path, f"base_model_run{run}.joblib")
        joblib.dump(base_model, base_model_path)
        print(f"已保存原始模型到: {base_model_path}")
        f1 = -1
        if X_val is not None:
            decision_values = base_model.decision_function(X_val)
            proba_sigmoid = sigmoid(decision_values)
            y_pred = (proba_sigmoid >= 0.5).astype(np.int8)
            recall = recall_score(y_val, y_pred)
            f1 = f1_score(y_val, y_pred)
            print(f"验证召回率: {recall:.4f} | 验证F1分数: {f1:.4f} | 用时: {time.time() - start:.1f}s")
        else:
            print(f"无验证集，跳过验证评估 | 用时: {time.time() - start:.1f}s")
        if f1 > best_f1:
            best_f1 = f1
            best_model = base_model
            print(f"更新最佳模型 | F1: {best_f1:.4f}")
    print("\n保存最佳模型和参数...")
    joblib.dump(best_model, os.path.join(save_path, "best_model.joblib"))
    np.save(os.path.join(save_path, "w.npy"), best_model.coef_[0])
    np.save(os.path.join(save_path, "b.npy"), best_model.intercept_[0])
    print(f"已保存权重 w 和偏置 b 到 {save_path}")
    print("\n" + "=" * 40)
    print(f"第{fold_num}折 - 测试集评估...")
    results = []
    X_test, y_test, mask, sixth_col, full_true_label = load_test_data_v73(test_folder, fold_num, selected_features_idx)
    fold_test_path = os.path.join(test_folder, f"{fold_num}cross")
    test_file = os.path.join(fold_test_path, "combined_features_lab_z.mat")
    with h5py.File(test_file, 'r') as f:
        total_samples = f['all_features'][()].T.shape[0]
    full_proba = np.zeros(total_samples)
    full_y_pred = np.zeros(total_samples, dtype=np.int8)
    if X_test is not None:
        X_test_scaled, _ = preprocess_data(X_test)
        decision_values = best_model.decision_function(X_test_scaled)
        proba = sigmoid(decision_values)
        y_pred = (proba >= 0.5).astype(np.int8)
        full_proba[mask] = proba
        full_y_pred[mask] = y_pred
    quality_mask = (sixth_col == 1)
    if np.any(quality_mask):
        print(f"对第六列标签为1的样本进行线性插值，插值样本数: {np.sum(quality_mask)}")
        full_proba = linear_interpolation(full_proba, quality_mask)
    df = pd.DataFrame({
        'filtered_proba': full_proba,
        'predicted_label': full_y_pred,
        'true_label': full_true_label
    })
    df.to_csv(os.path.join(save_path, f"fold_{fold_num}_predictions.csv"), index=False)
    print(f"保存预测结果(含真实标签): fold_{fold_num}_predictions.csv")
    if y_test is not None:
        metrics = {
            'fold': fold_num,
            'accuracy': accuracy_score(y_test, y_pred),
            'precision': precision_score(y_test, y_pred),
            'recall': recall_score(y_test, y_pred),
            'f1': f1_score(y_test, y_pred)
        }
        results.append(metrics)
        print(f"\n第{fold_num}折分类报告（第五列标签为1的样本）:")
        print(classification_report(y_test, y_pred, target_names=["Non‑Seizure", "Seizure"]))
    else:
        print(f"\n第{fold_num}折无第五列标签为1的样本，无法生成分类报告")
        metrics = {'fold': fold_num, 'accuracy': np.nan, 'precision': np.nan, 'recall': np.nan, 'f1': np.nan}
        results.append(metrics)
    pd.DataFrame(results).to_csv(os.path.join(save_path, f"fold_{fold_num}_summary.csv"), index=False)
    print(f"\n第{fold_num}折测试完成！")
    return results

def run_feature_count_experiments():
    train_folder = r"G:\TJX\新整理的在线算法\xunlianji_z{1,10}"
    test_folder = r"G:\TJX\新整理的在线算法\ceshiji_z{1,10}"
    feature_root = r"G:\TJX\新整理的在线算法\feature_select"
    feature_counts = [5,10,15,20,25,30,35,40,45,50]
    output_parent = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    runs = 1
    for feature_count in feature_counts:
        save_base_path = my_folder(
            os.path.join(output_parent, f"trainsvm_cv_results—cife-{feature_count}")
        )
        print("\n" + "#" * 70)
        print(f"Starting five‑fold training with K={feature_count}")
        print(f"Output directory: {save_base_path}")
        print("#" * 70)
        all_results = []
        for fold in range(1, 6):
            current_fold_features = load_fold_features(
                feature_root, fold, feature_count
            )
            print("\n" + "=" * 60)
            print(
                f"K={feature_count}, fold {fold}: "
                f"using feature indices {current_fold_features}"
            )
            print("=" * 60)
            fold_results = full_pipeline(
                train_folder=train_folder,
                test_folder=test_folder,
                fold_num=fold,
                selected_features_idx=current_fold_features,
                save_base_path=save_base_path,
                c_value=64,
                runs=runs
            )
            all_results.extend(fold_results)
        all_results_df = pd.DataFrame(all_results)
        all_results_df.to_csv(
            os.path.join(save_base_path, "all_folds_summary.csv"), index=False
        )
        avg_metrics = {
            "average_accuracy": all_results_df["accuracy"].mean(),
            "average_precision": all_results_df["precision"].mean(),
            "average_recall": all_results_df["recall"].mean(),
            "average_f1": all_results_df["f1"].mean(),
        }
        pd.DataFrame([avg_metrics]).to_csv(
            os.path.join(save_base_path, "average_metrics.csv"), index=False
        )
        print(f"Completed K={feature_count}; results saved to {save_base_path}")

if __name__ == "__main__":
    run_feature_count_experiments()