
/*
* �������ƣ�exfMean��
* �������ܣ���ȡһά�����ľ�ֵ��
* ���������x -- ��������ָ�룬ָ�������double*��
*       len_x -- x��Ԫ����Ŀ��������int��
*        winN -- ���ݴ�����������int��
*     overlap -- �ص����ݵ�����������int��
*     feature -- ��������ָ�룬ָ�������double*��
* len_feature -- �������ĳ��ȣ�������int��
* ����ֵ���ޡ�
*/
void exfMean(const double *x, const int winN, const int overlap, float *feature,

             const int len_feature) {
	// ��ΪwinN��overlap���ǹ̶��ģ����������ʵ����ȥ��winN��overlap�������룬ֱ�Ӹ�ֵΪ200��0��
	// ע�������winN�ͺ����������ʱ��ͬ��������һ������Ҫ��ֵ����

	int i, j;
	int s1;
	float sum;

	//���ջ��������������feature�еĽ��
	for (i = 0; i < len_feature; i++) {
		s1 = (winN - overlap) * i;
		sum = 0.0;//��һ��sum�洢���ݴ�������֮��

		for (j = s1; j < s1 + winN; j++) {
			sum += x[j];
		}
		feature[i] = sum / winN;//��ȡ���ݴ������ݵľ�ֵ
	}
}
