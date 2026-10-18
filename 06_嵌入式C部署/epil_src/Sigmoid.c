#include <stdio.h>
#include <math.h>

/*
* 函数名称： Sigmoid
* 函数功能： Sigmoid 函数
* 输入参数： x：变量，double类型。
* 返回值：folat类型
*/
// Sigmoid 函数
double sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
}

int main() {

    // double x = 2.0;

    // // 计算 x 的 Sigmoid 值
    // double result = sigmoid(x);

    // // 打印结果
    // printf("Sigmoid(%f) = %f\n", x, result);

    return 0;
}
