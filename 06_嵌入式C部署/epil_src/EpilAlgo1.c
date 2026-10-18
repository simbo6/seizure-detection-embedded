#include <math.h>
#include "exfMean.h"

#include "filtering_acc.h"
#include "filtering_other.h"
#include "calFeature1.h"
#include "calFeature2_plus.h"
#include "EpilAlgo1.h"
#include <string.h>

// 计算两个点之间的欧几里得距离的平�?
double distanceSquared(double *point1, double *point2, int dimensions) {
    double sum = 0;
    for (int i = 0; i < dimensions; i++) {
        sum += pow(point1[i] - point2[i], 2);
    }
    return sqrt(sum);
}

// 计算FCM隶属度矩�?U
//这里也做了对应修�?主要是center的维度，不清楚调用时究竟调用此处的函数还是外面额外的iterU函数
void iterU(double X[], double center[][2], double U[], int numClusters, int dimensions, double b) {
// void iterU(double X[], double center[][3], double U[], int numClusters, int dimensions, double b) {
    b = 2 / (b - 1);

    for (int i = 0; i < numClusters; i++) {
        double numerator = distanceSquared(center[i], X, dimensions);
        double denominatorSum = 0;

        for (int k = 0; k < numClusters; k++) {
            denominatorSum += pow(numerator / distanceSquared(center[k], X, dimensions), b);
        }

        U[i] = 1 / denominatorSum;
    }

  // 归一�?U
    double sum = 0;
    for (int i = 0; i < numClusters; i++) {
        sum += U[i];
    }
    for (int i = 0; i < numClusters; i++) {
        U[i] /= sum;
    }
}

// SVM 预测函数
double SVM(const double x[], const double w[], double b, int featuresNum) {
    double fit = 0;

  // 计算点积 (x * w)
    for (int i = 0; i < featuresNum; i++) {
        fit += x[i] * w[i];
    }

  // 加上偏置�?
    fit += b;

    return fit;
}

// Sigmoid 函数
double sigmoid(double x) {
    return 1 / (1 + exp(-x));
}

//标准化，zscore
void Zscore(const double x[], const double mean[], const double stdDev[], int x_N, double result[]) {
    for (int i = 0; i < x_N; ++i) {
        result[i] = (x[i] - mean[i]) / stdDev[i];
    }
}


// 宏定�?
#define ROWS 300  // 加速度、角速度原始数据行数、列�?
#define COLS 3

void calculateAcc41(float acc[][COLS], double acc_filtfilt[]) {
    int i, j;
    for (i = 0; i < ROWS; i++) {
        float sum = 0.0f;
        for (j = 0; j < COLS; j++) {
            const double value = (double)acc[i][j];
            sum += value * value;
        }
        acc_filtfilt[i] = (double)(float)sqrt((double)sum);
    }
}

void calculateGyr41(float gyr[][COLS], double gyr_filtfilt[]) {
    int i, j;
    for (i = 0; i < ROWS; i++) {
        float sum = 0.0f;
        for (j = 0; j < COLS; j++) {
            const double value = (double)gyr[i][j];
            sum += value * value;
        }
        gyr_filtfilt[i] = (double)(float)sqrt((double)sum);
    }
}

// 最大最小函�?
#define SIZE 6

float findMax(const float sqi[]) {
    float maxVal = sqi[0];
    int i;
    for (i = 1; i < SIZE; i++) {
        if (sqi[i] > maxVal) {
            maxVal = sqi[i];
        }
    }
    return maxVal;
}

float findMin(const float sqi[]) {
    float minVal = sqi[0];
    int i;
    for (i = 1; i < SIZE; i++) {
        if (sqi[i] < minVal) {
            minVal = sqi[i];
        }
    }
    return minVal;
}


double EpilAlgo1(float acc[300][3], float gyr[300][3], float emg[1200]) {
    double fit;

    // 预处�?
    int len_acc = 300;
    int len_emg = 1200;
    int fs_acc = 50;
    int fs_emg = 200;
    static double acc_filtfilt[300];
    static double gyr_filtfilt[300];
    static double emg_filtfilt[1200];

    // 额外加一步实现对ACC限幅
    for (int i = 0; i < 300; i++) {
        for(int j = 0; j < 3; j++){
        if (acc[i][j] > 19.6f) {
            acc[i][j] = 19.6f;
        } else if (acc[i][j] < -19.6f) {
            acc[i][j] = -19.6f;
        }
    }
    }

    
    calculateAcc41(acc, acc_filtfilt);



        // 滤波
    for (int i = 0; i < 1200; i++) {
            emg_filtfilt[i] = (double)emg[i];
    }

   
#if 0
    
    filtering_other(emg_filtfilt, len_emg,   emg_filtfilt);//对肌电滤�?
    for (int i = 0; i < 1200; i++) {
        if (emg_filtfilt[i] > 8.5f) {
            emg_filtfilt[i] = 8.5f;
        } else if (emg_filtfilt[i] < -8.5f) {
            emg_filtfilt[i] = -8.5f;
        }
    }

    float sqi[6];
    exfMean(emg_filtfilt, 200, 0, sqi, 6);// 是否异常数据：肌电的基线漂移
        
    double sqi0 = findMax(sqi) - findMin(sqi);
    int logical_ab = 0;

    if (sqi0 > 0.02) {//修改，由70-3 - 0.02
        logical_ab = 1;
    }

        if (logical_ab == 1) { // 如果异常，则不进行特征提取，直接返回NaN

            fit = NAN; // 信号质量不好，该样本不进行分类，fit设置为NaN

        } else 

#endif

		{// 否则进行分类

            filtering_acc(acc_filtfilt, len_acc,  acc_filtfilt);
            
            
       // 特征提取
                 // 节省中间变量的版本：
            double testset1[2];  memset(testset1, 0, 2 * sizeof(double));   // 需要初始化�?
            calFeature1(acc_filtfilt, len_acc, &(testset1[0]),  &(testset1[1]));// feature 1
          // 此函数的确是改在了原函数�?故调用函数时不用加plus版本
            

        // 标准�?
            double PS1_mean[] = {0.751154510629854,0.103658990654803,};
            double PS1_stdDev[] = {0.313486109774186,1.027469024842195,};
              // 节省中间变量的版本：
            // Zscore(testset1, PS1_mean, PS1_stdDev, 3, testset1);
            double testset3[2];
            testset3[0] = testset1[0];
            testset3[1] = testset1[1];

            Zscore(testset3, PS1_mean, PS1_stdDev, 2, testset3);//



            // Clustering  鑱氱被

            // 获取 b = mdl_FCM(1, end);
            double b = 1.199999999999999955591079014993738383054733276367187500000000; // 妯＄硦锟?

            double mdl_FCM_2[][2] = {// 由原来的mdl_FCM_2[][3]变为前文所�?
                    {-0.184073531433531,-0.078691624454041,},
                    {3.661696840615507,1.523671599834950,}
                        

            }; //center 聚类中心 iterU的参数center[][3]
            // 初始化聚类中心和隶属度矩�?fit_FCM
            int numClusters = 2;  // 聚类中心数量，每个聚类中心的维度在上面的 center 数组中体�?
            // 分配空间来存储隶属度矩阵 fit_FCM   numPoints × numClusters 1×2
            double fit_FCM[2];
           // 计算隶属度矩�?fit_FCM
            // iterU(testset1, mdl_FCM_2, fit_FCM, numClusters, 3, b);
            iterU(testset3, mdl_FCM_2, fit_FCM, numClusters, 2, b);// FCM
            double fit_FCM_2 = fit_FCM[1]; //数组�?0 开�? // To：梁彤文，这里的fit_FCM_2应该是double！！�?
            int pred = fit_FCM_2 >= 0.5 ? 1 : 0;


        // 运动判断
            if (pred == 0) 
			{ //聚类结果为非运动，fit设为0

                fit = 0;

            } 
			else 
			{

			     filtering_other(emg_filtfilt, len_emg,   emg_filtfilt);// EMG filter
			     for (int i = 0; i < 1200; i++) {
			         if (emg_filtfilt[i] > 8.5f) {
			             emg_filtfilt[i] = 8.5f;
			         } else if (emg_filtfilt[i] < -8.5f) {
			             emg_filtfilt[i] = -8.5f;
			         }
			     }

			     float sqi[6];
			     exfMean(emg_filtfilt, 200, 0, sqi, 6); // 是否异常数据：肌电的基线漂移
			        
			     double sqi0 = findMax(sqi) - findMin(sqi);
			     int logical_ab = 0;

			     if (sqi0 > 0.02) {//修改，由70-3 - 0.02
			         logical_ab = 1;
			     }

			         if (logical_ab == 1) {// 如果异常，则不进行特征提取，直接返回NaN

			             fit = NAN; // 信号质量不好，该样本不进行分类，fit设置为NaN

			         } else { // 否则进行分类
	                                calculateGyr41(gyr, gyr_filtfilt);
	                                filtering_acc(gyr_filtfilt, len_acc,  gyr_filtfilt);
			                                        
			                    // 特征提取
			                    // void calFeature2_plus(const double *acc_filtfilt, const double *gyr_filtfilt, const double *emg_filtfilt,
			                    //      const int len_acc, const int len_emg, const int fs_acc, const int fs_emg,
			                    //      double *acc9, double *acc14, double *acc26, double *acc23, double *acc15, double *acc10, double *acc4,double *acc25,
			                    //      double *gyr1, double *gyr25, double *gyr9, double *gyr10, double *gyr8, double *gyr4, double *gyr19,double *gyr22, 
			                    //      double *emg7, double *emg1, double *emg17, double *emg10, double *emg9, double *emg8,double *emg2) {
			                                // 节省中间变量的版本：
			                                double testset2[25];  memset(testset2, 0, 25 * sizeof(double));  // 闇€瑕佸垵濮嬪寲锟?
				                                calFeature2_plus(acc_filtfilt, gyr_filtfilt, emg_filtfilt, len_acc, len_emg, fs_acc, fs_emg,
			                                &(testset2[1]), &(testset2[2]), &(testset2[3]), &(testset2[4]), &(testset2[5]), &(testset2[6]), &(testset2[8]), &(testset2[9]),
			                                &(testset2[10]), &(testset2[11]), &(testset2[12]), &(testset2[13]), &(testset2[14]), &(testset2[15]), &(testset2[16]),&(testset2[17]),
				                                &(testset2[18]), &(testset2[19]), &(testset2[20]), &(testset2[21]), &(testset2[22]), &(testset2[23]), &(testset2[24]));
			                                 // 这里有较大变�?首先特征数目和含义有了变�?其次特征排序按照acc,gyr,emg方式,这里是比较容易出错的地方
			                                
			                    // 标准�?
			                                double PS2_mean[] = {0.751168438628426,
                                                                24.036648601673605,
                                                                1.387735888556230,
                                                                0.834945566921085,
                                                                0.740576152806068,
                                                                8.782028818136290,
                                                                56.950598361733462,
                                                                0.103728902882642,
                                                                0.821160127610095,
                                                                0.040450036686928,
                                                                1.077892123193777,
                                                                1.929616185468634,
                                                                6.038105039018980,
                                                                0.510418008746198,
                                                                0.089327498437222,
                                                                0.060520726577139,
                                                                3.391954097566164,
                                                                4.204427321846165,
                                                                0.014711805895489,
                                                                0.776920740286250,
                                                                0.022427758865793,
                                                                1.436548123078419,
                                                                18.688237412803186,
                                                                1.199318318584508e+03,
                                                                0.506944142711256,};
			                                double PS2_stdDev[] = {0.313528016424706,
                                                                    5.753979740475470,
                                                                    0.332153401198121,
                                                                    0.500338331459704,
                                                                    0.351944296766307,
                                                                    4.044695951312161,
                                                                    58.671487405180265,
                                                                    1.027967238288550,
                                                                    0.075932976529741,
                                                                    0.024096346408166,
                                                                    0.448102205042326,
                                                                    0.504641758517071,
                                                                    11.019600715023758,
                                                                    0.216028796632732,
                                                                    0.068930937642511,
                                                                    0.054123983214431,
                                                                    1.981726204773109,
                                                                    1.699551594691194,
                                                                    0.011853762856882,
                                                                    0.912656740890712,
                                                                    0.026346126828279,
                                                                    44.461469948862430,
                                                                    16.634692746633469,
                                                                    7.746195004519755,
                                                                    4.930320048822702,};
			                                 // 节省中间变量的版本：
                                            testset2[0] = testset1[0];   
			                                testset2[7] = testset1[1];  
			                    Zscore(testset2, PS2_mean, PS2_stdDev, 25, testset2);

			                                // testset2[24] = testset1[1];  // gyr1
			                                
			                                                                            
			                                
			                    // SVM分类  计算fit
			                    double w[] = {2.35219666e-01,
                                            1.03280248e+01,
                                            -1.03661276e+01,
                                            -2.50539733e-01,
                                            1.39306272e-01,
                                            7.93912381e-02,
                                            -7.96586685e-02,
                                            -4.72404967e-03,
                                            -1.63367164e-01,
                                            1.53154609e-02,
                                            1.89116658e-02,
                                            -5.45532847e-02,
                                            8.70855184e-02,
                                            2.46910455e-01,
                                            -3.07386602e-01,
                                            -2.37854342e-01,
                                            -6.12536554e-01,
                                            1.65042568e+00,
                                            -9.41215998e-02,
                                            2.17005170e-01,
                                            -1.67824029e-01,
                                            -2.61909134e-02,
                                            1.22222661e-01,
                                            9.87400995e-02,
                                            1.13173328e-01,
			                    };
			                    double b_model = -1.7807615829230603;
			                    double f_x = SVM(testset2, w, b_model, 25);  // f_x = testFeatures * w + b_model;
			                                
	                                fit = sigmoid(f_x);
							}

						}
    }
    return fit;
}
