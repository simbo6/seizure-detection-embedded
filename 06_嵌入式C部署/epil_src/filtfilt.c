/*
* 函数名称：filter。
* 函数功能：对不定长的数组进行滤波。
* 输入参数：b -- 滤波参数，指针变量，double*。
*           a -- 滤波参数，指针变量，double*。
*           x -- 输入数据指针，指针变量，double*。
*       len_a -- a、b的元素数目，标量，int。zi的元素数目为len_a - 1。
*       len_x -- x、y的元素数目，标量，int。
*          zi -- 滤波参数，指针变量，double*。
*           y -- 滤波结果指针（函数结果），指针变量，double*。
* 返回值：无。
*/
void filter(const double *b, const double *a, const double *x, const int len_a, const int len_x,

            double *y) {
	/*
	在matlab中，filter函数的代码是不公开的，因此无法进行参考。
	参考的代码是李雯编写的myfilter函数，此函数经对比发现和matlab自带的filter函数存在10的-7次方左右的误差。
	在这里，基于myfilter在这里实现的filter函数，经测试最多仅能保证6位小数的精度，即误差同样在10的-7次方左右。
	*/

	// 初始化各种参数
	int i, j;
	int order = len_a - 1;

	// y进行初始化操作，注意这里x参与后续计算，因此必须有一个额外的y来存储数据
	for (i = 0; i < len_x; i++) {
		y[i] = x[i];
	}

    // 这里的置零操作是多余的，故注释
//    //a[0]置零
//    ar[order] = 0;

	// 对前面order个点计算滤波
	for (i = 0; i < order; i++) {
		y[i] = b[0] * x[i];
		for (j = 1; j <= i; j++) {
			y[i] += b[j] * x[i - j] - a[j] * y[i - j];
		}
	}

	// 对后面的点计算滤波
	for (i = order; i < len_x; i++) {
		y[i] = b[0] * x[i];
		for (j = 1; j <= order; j++) {
			y[i] += b[j] * x[i - j] - a[j] * y[i - j];
		}
	}

}
