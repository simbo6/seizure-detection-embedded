#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// /*
// * 函数名称：distanceSquared
// * 函数功能：计算两个点之间的欧几里得距离的平方。
// * 输入参数： point1：点1，一维数组，double类型。
// *           point2：点2，一维数组，double类型。
// *           dimensions：维度，变量，int类型。  
// * 返回值：sum，变量，double类型。
// */
// 计算两个点之间的欧几里得距离的平方
double distanceSquared(double* point1, double* point2, int dimensions) {
    double sum = 0.0;
    for (int i = 0; i < dimensions; i++) {
        sum += pow(point1[i] - point2[i], 2);
    }
    return sum;
}

/*
* 函数名称：iterU
* 函数功能：计算FCM的隶属度矩阵 U
* 输入参数： X[]：一个数据点的特征 数组，double类型。
*           center：聚类中心矩阵，每一行是一个聚类中心, 聚类中心数量×维度，double类型二维数组。
*           b：模糊度参数，变量，double类型。  
*           numClusters: 聚类中心的数量，变量，int型。
*           dimensions：维度，center的列数，这里是三列，变量，int类型。
*           U: 隶属度数组 U  double类型一维数组。
* 返回值：无
*/
// 计算FCM隶属度 U
void iterU(double X[], double center[][2], double U[], int numClusters, int dimensions, double b) {
    //修改,主要是center[][3]变为center[][2]
    b = 2.0 / (b - 1.0);

    for (int i = 0; i < numClusters; i++) {
        double numerator = distanceSquared(center[i], X, dimensions);
        double denominatorSum = 0.0;

        for (int k = 0; k < numClusters; k++) {
            denominatorSum += pow(numerator / distanceSquared(center[k], X, dimensions), b);
        }

        U[i] = 1.0 / denominatorSum;
    }

    // 归一化 U
    double sum = 0.0;
    for (int i = 0; i < numClusters; i++) {
        sum += U[i];
    }
    for (int i = 0; i < numClusters; i++) {
        U[i] /= sum;
    }
}

int main() {
    // X 数据点特征
    double X[] = {
        -0.414336115928097, -0.481598998523669, -0.0913889693353479
    };

    // 两个聚类中心，每个聚类中心有3个维度
    double center[][3] = {
        {-0.245884871349530, -0.250767167557067, -0.0769558355560320},
        {2.55806380189189, 2.60692253455006, 0.768263092875616}
    };

    int numClusters = sizeof(center) / sizeof(center[0]);  // 聚类中心数量，每个聚类中心的维度在上面的 center 数组中体现
    double b = 1.2;  // 模糊度

    // 隶属度矩阵 U
    double U[numClusters];

    // 计算FCM隶属度矩阵 U
    iterU(X, center, U, numClusters, 3, b);

    // 打印结果
    for (int i = 0; i < numClusters; i++) {
        printf("U[%d] = %f  ", i, U[i]);
    }
    printf("\n");

    return 0;
}
