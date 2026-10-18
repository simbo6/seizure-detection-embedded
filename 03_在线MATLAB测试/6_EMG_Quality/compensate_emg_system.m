function y=compensate_emg_system(x,fs)
%COMPENSATE_EMG_SYSTEM 复现原 ifftt.m 的系统幅频响应逆补偿。
y=double(x(:)).'; nan_idx=isnan(y);
if any(nan_idx)
    valid_idx=find(~nan_idx);
    if isempty(valid_idx), y(:)=NaN; y=y.'; return, end
    y(nan_idx)=interp1(valid_idx,y(valid_idx),find(nan_idx),'linear','extrap');
end
N=length(y); Y=fft(y); f=(0:N-1)*(fs/N);
f_meas=[1,5:5:100];
gain_meas=[1,14.40,33.30,61.10,95.70,135.40,177.50,219.80,259.20,306.90,342.20,382.60,426.50,470.20,506.30,535.00,553.50,599.90,622.90,652.80,600]/2;
G=interp1(f_meas,gain_meas,f,'linear'); H_inv=zeros(size(G));
H_inv(G>1e-6)=1./G(G>1e-6); y=real(ifft(Y.*H_inv)).';
end
