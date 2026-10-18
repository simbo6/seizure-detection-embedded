import numpy as np
import os
import h5py
from sklearn.svm import LinearSVC
from sklearn.calibration import CalibratedClassifierCV
from sklearn.model_selection import train_test_split
from sklearn.metrics import f1_score, accuracy_score, precision_score, recall_score, classification_report
import joblib
import pandas as pd
from tqdm import tqdm
import time


# 新增：定义sigmoid函数（原代码中引用但未定义）
def sigmoid(x):
    return 1 / (1 + np.exp(-x))


def my_folder(path):
    if not os.path.exists(path):
        os.makedirs(path)
    return path


def load_training_data_v73(train_folder, fold_num, selected_features_idx, save_path):
    """
    加载五折交叉验证的训练数据（v7.3格式）
    Args:
        train_folder: 训练集主文件夹路径 (xunlianji)
        fold_num: 折数 (1-5)
        selected_features_idx: 指定的特征列索引（从0开始），如[0,7,25]对应原代码的[1,8,26]
        save_path: 保存路径
    """
    # 拼接当前折的训练集路径
    fold_train_path = os.path.join(train_folder, f"{fold_num}cross")
    features_file = os.path.join(fold_train_path, "combined_features_z.mat")
    lab_file = os.path.join(fold_train_path, "combined_lab_z.mat")

    # 加载特征数据
    with h5py.File(features_file, 'r') as f:
        # 读取all_features并选择指定特征列
        X = f['all_features'][()].T  # (samples, 71)
        X = X[:, selected_features_idx]  # 选择指定特征列

    # 加载标签数据
    with h5py.File(lab_file, 'r') as f:
        lab = f['train_all_lab_raw'][()].T  # (samples, 6)
        y = lab[:, 0].astype(np.int8)  # 第一列为分类标签
        fifth_col = lab[:, 4].astype(np.int8)  # 第五列用于筛选

    # 原有降采样逻辑保持不变
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

    # 合并发作和降采样的非发作样本
    X_combined = np.vstack((X_seizure, X_non_seizure_sampled))
    y_combined = np.concatenate((y_seizure, y_non_seizure_sampled))
    fifth_col_combined = np.concatenate((fifth_col_seizure, fifth_col_non_seizure_sampled))

    # 筛选第五列为1的样本
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
    """
    加载五折交叉验证的测试数据（v7.3格式）
    Args:
        test_folder: 测试集主文件夹路径 (ceshiji)
        fold_num: 折数 (1-5)
        selected_features_idx: 指定的特征列索引（从0开始）
    """
    # 拼接当前折的测试集路径
    fold_test_path = os.path.join(test_folder, f"{fold_num}cross")
    test_file = os.path.join(fold_test_path, "combined_features_lab_z.mat")

    with h5py.File(test_file, 'r') as f:
        # 读取特征并选择指定列
        X = f['all_features'][()].T  # (samples, 71)
        X = X[:, selected_features_idx]  # 选择指定特征列

        lab = f['test_all_lab_raw'][()].T  # (samples, 6)
        y = lab[:, 0].astype(np.int8)  # 第一列为分类标签
        fifth_col = lab[:, 4].astype(np.int8)  # 第五列用于筛选
        sixth_col = lab[:, 5].astype(np.int8)  # 第六列为质量标签

    # 筛选第五列为1的样本
    mask = (fifth_col == 1)
    X_filtered = X[mask]
    y_filtered = y[mask]

    if len(X_filtered) == 0:
        print(f"警告：第{fold_num}折测试集中没有第五列标签为1的样本，预测结果全为0")
        # 返回完整原始真实标签 y 用于后续csv保存
        return None, None, mask, sixth_col, y

    print(f"\n第{fold_num}折测试集加载完成")
    print(f"原始样本数: {len(y)}，筛选后（第五列标签为1）: {len(y_filtered)}")
    print(f"特征矩阵形状: {X_filtered.shape} (选择了{len(selected_features_idx)}个特征)")
    print(f"标签分布: {dict(zip(*np.unique(y_filtered, return_counts=True)))}")
    return X_filtered, y_filtered, mask, sixth_col, y


def preprocess_data(X, scaler=None):
    """直接返回原始数据（已标准化）"""
    print(f"跳过额外预处理，数据形状: {X.shape}")
    return X, None


def load_fold_features(feature_root, fold_num, feature_count):
    """Load one fold's MATLAB feature-selection result for the requested K.

    MATLAB writes 1-based feature indices in ``all_k_selected_features.csv``;
    this function converts them to the 0-based indices expected by NumPy.
    """
    csv_path = os.path.join(
        feature_root, "xunlianji_feature{1,10}", f"{fold_num}cross",
        "all_k_selected_features.csv"
    )
    if not os.path.isfile(csv_path):
        raise FileNotFoundError(f"Missing feature-selection result: {csv_path}")

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
    """对掩码为True的区域进行线性插值"""
    interpolated_data = data.copy()
    indices = np.arange(len(data))
    valid_mask = ~mask  # 非插值区域（质量合格）
    if np.sum(valid_mask) < 2:
        print("警告：有效数据点不足，无法进行线性插值，返回原数据")
        return interpolated_data
    interpolated_data[mask] = np.interp(
        indices[mask],  # 需要插值的索引
        indices[valid_mask],  # 有效数据的索引
        data[valid_mask]  # 有效数据的概率值
    )
    return interpolated_data


def full_pipeline(train_folder, test_folder, fold_num, selected_features_idx, save_base_path, runs=1):
    """
    主处理流程（适配五折交叉验证）
    Args:
        train_folder: 训练集主文件夹路径 (xunlianji)
        test_folder: 测试集主文件夹路径 (ceshiji)
        fold_num: 当前折数 (1-5)
        selected_features_idx: 指定的特征列索引（从0开始）
        save_base_path: 保存基础路径
        runs: 训练轮数
    """
    # 为当前折创建独立的保存路径
    save_path = my_folder(os.path.join(save_base_path, f"fold_{fold_num}"))

    # 1. 加载并处理训练数据
    print("\n" + "=" * 40)
    print(f"第{fold_num}折 - 加载并处理训练数据...")
    X_train, y_train = load_training_data_v73(train_folder, fold_num, selected_features_idx, save_path)

    # 2. 数据预处理
    print("\n进行数据预处理...")
    X_train_scaled, _ = preprocess_data(X_train)

    # 3. 划分训练验证集
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

    # 4. 模型训练（原有逻辑不变）
    print("\n" + "=" * 40)
    print(f"第{fold_num}折 - 开始模型训练...")
    best_model = None
    best_base_model = None
    best_score = -1
    best_f1 = -1

    for run in range(1, runs + 1):
        start = time.time()
        print(f"\nRun {run}/{runs}")

        # 训练线性SVM基模型
        base_model = LinearSVC(
            C=64,  # 调整正则化参数
            class_weight='balanced',
            max_iter=2000,  # 增加迭代次数
            random_state=42 + run,
            dual=False
        )
        base_model.fit(X_train_split, y_train_split)
        print(
            f"训练集样本数: {len(y_train_split)}, 标签分布: {dict(zip(*np.unique(y_train_split, return_counts=True)))}")

        base_model_path = os.path.join(save_path, f"base_model_run{run}.joblib")
        joblib.dump(base_model, base_model_path)
        print(f"已保存原始模型到: {base_model_path}")

        # 验证集评估
        if X_val is not None:
            decision_values = base_model.decision_function(X_val)
            proba_sigmoid = sigmoid(decision_values)  # 使用sigmoid转换
            y_pred = (proba_sigmoid >= 0.5).astype(np.int8)  # 阈值0.5分类
            recall = recall_score(y_val, y_pred)
            f1 = f1_score(y_val, y_pred)
            print(f"验证召回率: {recall:.4f} | 验证F1分数: {f1:.4f} | 用时: {time.time() - start:.1f}s")
        else:
            recall = -1
            f1 = -1
            print(f"无验证集，跳过验证评估 | 用时: {time.time() - start:.1f}s")

        # 以F1分数为主要指标选择最佳模型
        if f1 > best_f1:
            best_f1 = f1
            best_score = recall
            best_model = base_model
            print(f"更新最佳模型 | F1: {best_f1:.4f} | Recall: {best_score:.4f}")

    # 保存模型和参数
    print("\n保存最佳模型和参数...")
    joblib.dump(best_model, os.path.join(save_path, "best_model.joblib"))
    np.save(os.path.join(save_path, "w.npy"), best_model.coef_[0])
    np.save(os.path.join(save_path, "b.npy"), best_model.intercept_[0])
    print(f"已保存权重 w 和偏置 b 到 {save_path}")

    # 6. 测试集评估
    print("\n" + "=" * 40)
    print(f"第{fold_num}折 - 测试集评估...")
    results = []

    # 加载当前折的测试数据（新增full_true_label返回值）
    X_test, y_test, mask, sixth_col, full_true_label = load_test_data_v73(test_folder, fold_num, selected_features_idx)

    # 扩展预测结果到原始样本长度
    # 重新读取测试集文件获取总样本数
    fold_test_path = os.path.join(test_folder, f"{fold_num}cross")
    test_file = os.path.join(fold_test_path, "combined_features_lab_z.mat")
    with h5py.File(test_file, 'r') as f:
        total_samples = f['all_features'][()].T.shape[0]

    full_proba = np.zeros(total_samples)
    full_y_pred = np.zeros(total_samples, dtype=np.int8)

    if X_test is not None:
        X_test_scaled, _ = preprocess_data(X_test)
        decision_values = best_model.decision_function(X_test_scaled)
        proba = sigmoid(decision_values)  # 使用sigmoid转换
        y_pred = (proba >= 0.5).astype(np.int8)  # 阈值0.5分类
        full_proba[mask] = proba
        full_y_pred[mask] = y_pred

    # 对第六列标签为1的样本进行线性插值
    quality_mask = (sixth_col == 1)
    if np.any(quality_mask):
        print(f"对第六列标签为1的样本进行线性插值，插值样本数: {np.sum(quality_mask)}")
        full_proba = linear_interpolation(full_proba, quality_mask)

    # ========== 修改点：增加真实标签列 true_label ==========
    df = pd.DataFrame({
        'filtered_proba': full_proba,
        'predicted_label': full_y_pred,
        'true_label': full_true_label   # 新增第三列：原始真实发作标签
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
        print(classification_report(y_test, y_pred, target_names=["Non-Seizure", "Seizure"]))
    else:
        print(f"\n第{fold_num}折无第五列标签为1的样本，无法生成分类报告")
        metrics = {'fold': fold_num, 'accuracy': np.nan, 'precision': np.nan, 'recall': np.nan, 'f1': np.nan}
        results.append(metrics)

    # 保存当前折的评估结果
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
            os.path.join(output_parent, f"trainsvm_cv_results—{feature_count}")
        )
        print("\n" + "#" * 70)
        print(f"Starting five-fold training with K={feature_count}")
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





def legacy_main():
    # ====================== 配置参数 ======================
    # ============ 核心开关：True=全部71特征训练；False=每折使用自定义特征 ============
    USE_ALL_FEATURES = True
    # 1. 数据集路径（替换为你的实际路径）
    TRAIN_FOLDER = r"G:\TJX\新整理的在线算法\xunlianji_z{1,10}"  # 训练集主文件夹
    TEST_FOLDER = r"G:\TJX\新整理的在线算法\ceshiji_z{1,10}"  # 测试集主文件夹

    # ==========核心：五折各自独立的特征索引列表（USE_ALL_FEATURES=False时生效）==========
    # FOLD_FEATURES[0] -> fold1特征, FOLD_FEATURES[1]->fold2特征 ... FOLD_FEATURES[4]->fold5特征
    FOLD_FEATURES = [
        # fold 1 特征索引
        [0, 2, 3, 4, 5, 6, 7, 8, 37, 48, 50, 51, 52, 53, 54, 56, 57, 58, 59, 70],
        # fold 2 特征索引（自行修改每一折特征）
        [0, 4, 5, 6, 8, 20, 37, 45, 50, 51, 52, 53, 54, 56, 57, 58, 59, 64, 66, 70],
        # fold 3 特征索引
        [0, 2, 3, 4, 5, 6, 8, 45, 48, 49, 50, 51, 52, 53, 54, 56, 57, 58, 64, 70],
        # fold 4 特征索引
        [0, 2, 3, 4, 5, 6, 8, 45, 48, 49, 50, 51, 52, 53, 54, 56, 57, 58, 64, 70],
        # fold 5 特征索引
        [0, 2, 3, 4, 5, 6, 8, 45, 48, 49, 50, 51, 52, 53, 54, 56, 57, 58, 64, 70]
    ]

    # 3. 保存路径
    SAVE_BASE_PATH = my_folder("../trainsvm_cv_results—71_2000")

    # 4. 训练轮数
    RUNS = 1

    # ====================== 五折交叉验证主流程 ======================
    all_results = []
    for fold in range(1, 6):  # 1-5折
        print("\n" + "=" * 60)
        print(f"开始处理第 {fold} 折交叉验证")
        print("=" * 60)

        # 特征选择分支
        if USE_ALL_FEATURES:
            # 使用全部71个特征：索引0~70
            current_fold_feature = list(range(71))
            print(f"当前第{fold}折启用全特征训练，特征总数：{len(current_fold_feature)}")
        else:
            # 沿用自定义分折特征
            current_fold_feature = FOLD_FEATURES[fold - 1]
            print(f"当前第{fold}折使用自定义特征数量：{len(current_fold_feature)}，特征索引：{current_fold_feature}")

        # 运行当前折的训练和测试，传入当前折特征
        fold_results = full_pipeline(
            train_folder=TRAIN_FOLDER,
            test_folder=TEST_FOLDER,
            fold_num=fold,
            selected_features_idx=current_fold_feature,
            save_base_path=SAVE_BASE_PATH,
            runs=RUNS
        )
        all_results.extend(fold_results)

    # 保存所有折的汇总结果
    all_results_df = pd.DataFrame(all_results)
    all_results_df.to_csv(os.path.join(SAVE_BASE_PATH, "all_folds_summary.csv"), index=False)

    # 计算平均指标
    avg_metrics = {
        'average_accuracy': all_results_df['accuracy'].mean(),
        'average_precision': all_results_df['precision'].mean(),
        'average_recall': all_results_df['recall'].mean(),
        'average_f1': all_results_df['f1'].mean()
    }
    avg_df = pd.DataFrame([avg_metrics])
    avg_df.to_csv(os.path.join(SAVE_BASE_PATH, "average_metrics.csv"), index=False)

    print("\n" + "=" * 60)
    print("五折交叉验证全部完成！")
    print(f"平均准确率: {avg_metrics['average_accuracy']:.4f}")
    print(f"平均精确率: {avg_metrics['average_precision']:.4f}")
    print(f"平均召回率: {avg_metrics['average_recall']:.4f}")
    print(f"平均F1分数: {avg_metrics['average_f1']:.4f}")
    print(f"所有结果已保存到: {SAVE_BASE_PATH}")

if __name__ == "__main__":
    legacy_main()

# run_c_experiments()
# run_feature_count_experiments()
# legacy_main()