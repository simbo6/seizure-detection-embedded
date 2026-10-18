#include <stdio.h>
/*
* 函数名称： SVM
* 函数功能： SVM 预测函数
* 输入参数： x[]：特征数组，double类型数组。
*           w[]：权重数组，double类型数组。
*           b：偏置项参数，变量，double类型。  
*           featuresNum: 特征个数，变量，int型。 
* 返回值：fit：folat类型
*/

// SVM 预测函数
double SVM(double x[], double w[], double b, int featuresNum) {
    double fit = 0.0;

    // 计算点积 (x * w)
    for (int i = 0; i < featuresNum; i++) {
        fit += x[i] * w[i];
    }

    // 加上偏置项
    fit += b;

    return fit;
}

int main() {
    // 示例用法
    double x[] = {1.5, 2.0, 3.0};  // 特征值
    double w[] = {0.5, -0.8, 1.2}; // 权重值
    double b = -0.7;                // 偏置项
    int featuresNum = sizeof(x) / sizeof(x[0]);

    // 计算 SVM 拟合值
    double fit = SVM(x, w, b, featuresNum);

    // 打印结果
    printf("SVM 拟合值: %.2f\n", fit);

    return 0;
}
