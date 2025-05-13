setwd("C:/Users/funch/OneDrive/바탕 화면/고려대/2024/2학기/취뽀공주/NH투자증권 ETF 경진대회 본선/")
etf_sor_100_RMSE <- read.csv("본선용 데이터/rmse_nrmse_summary_all_etfs(etf_sor_100).csv", fileEncoding = "CP949", row.names = NULL)

# 히스토그램 생성 및 색상과 x축 레이블 지정
x11();hist(etf_sor_100_RMSE$Test.RMSE,  # 히스토그램 색상
     xlab = "etf_sor_100_RMSE Test RMSE Values",  # x축 레이블
     main = "")  # 그래프 제목 (필요에 따라 변경 가능)

# RMSE가 5 이하인 값의 개수 세기
count_rmse_below_5 <- sum(etf_sor_100_RMSE$Test.RMSE <= 5, na.rm = TRUE)
print(count_rmse_below_5)

###################################################################################
mm1_tot_pft_rt_RMSE <- read.csv("본선용 데이터/rmse_nrmse_summary_all_etfs(mm1_tot_pft_rt).csv", fileEncoding = "CP949", row.names = NULL)

# 히스토그램 생성 및 색상과 x축 레이블 지정
x11();hist(mm1_tot_pft_rt_RMSE$Test.RMSE,  # 히스토그램 색상
           xlab = "mm1_tot_pft_rt_RMSE Test RMSE Values",  # x축 레이블
           main = "")  # 그래프 제목 (필요에 따라 변경 가능)

# RMSE가 5 이하인 값의 개수 세기
count_rmse_below_5 <- sum(mm1_tot_pft_rt_RMSE$Test.RMSE <= 5, na.rm = TRUE)
print(count_rmse_below_5)


###################################################################################
mm3_tot_pft_rt_RMSE <- read.csv("본선용 데이터/rmse_nrmse_summary_all_etfs(mm3_tot_pft_rt).csv", fileEncoding = "CP949", row.names = NULL)

# 히스토그램 생성 및 색상과 x축 레이블 지정
x11();hist(mm3_tot_pft_rt_RMSE$Test.RMSE,  # 히스토그램 색상
           xlab = "mm3_tot_pft_rt_RMSE Test RMSE Values",  # x축 레이블
           main = "")  # 그래프 제목 (필요에 따라 변경 가능)

# RMSE가 5 이하인 값의 개수 세기
count_rmse_below_5 <- sum(mm3_tot_pft_rt_RMSE$Test.RMSE <= 5, na.rm = TRUE)
print(count_rmse_below_5)


###################################################################################
yr1_tot_pft_rt_RMSE <- read.csv("본선용 데이터/rmse_nrmse_summary_all_etfs(yr1_tot_pft_rt).csv", fileEncoding = "CP949", row.names = NULL)

# 히스토그램 생성 및 색상과 x축 레이블 지정
x11();hist(yr1_tot_pft_rt_RMSE$Test.RMSE,  # 히스토그램 색상
           xlab = "yr1_tot_pft_rt_RMSE Test RMSE Values",  # x축 레이블
           main = "")  # 그래프 제목 (필요에 따라 변경 가능)

# RMSE가 5 이하인 값의 개수 세기
count_rmse_below_5 <- sum(yr1_tot_pft_rt_RMSE$Test.RMSE <= 5, na.rm = TRUE)
print(count_rmse_below_5)


###################################################################################
crr_z_sor_100_RMSE <- read.csv("본선용 데이터/rmse_nrmse_summary_all_etfs(crr_z_sor_100).csv", fileEncoding = "CP949", row.names = NULL)

# 히스토그램 생성 및 색상과 x축 레이블 지정
x11();hist(crr_z_sor_100_RMSE$Test.RMSE,  # 히스토그램 색상
           xlab = "crr_z_sor_100_RMSE Test RMSE Values",  # x축 레이블
           main = "")  # 그래프 제목 (필요에 따라 변경 가능)

# RMSE가 5 이하인 값의 개수 세기
count_rmse_below_5 <- sum(crr_z_sor_100_RMSE$Test.RMSE <= 5, na.rm = TRUE)
print(count_rmse_below_5)

###################################################################################
mxdd_z_sor_100_RMSE <- read.csv("본선용 데이터/rmse_nrmse_summary_all_etfs(mxdd_z_sor).csv", fileEncoding = "CP949", row.names = NULL)

# 히스토그램 생성 및 색상과 x축 레이블 지정
x11();hist(mxdd_z_sor_100_RMSE$Test.RMSE,  # 히스토그램 색상
           xlab = "mxdd_z_sor_100_RMSE Test RMSE Values",  # x축 레이블
           main = "")  # 그래프 제목 (필요에 따라 변경 가능)

# RMSE가 5 이하인 값의 개수 세기
count_rmse_below_5 <- sum(mxdd_z_sor_100_RMSE$Test.RMSE <= 5, na.rm = TRUE)
print(count_rmse_below_5)


###################################################################################
vty_z_sor_100_RMSE <- read.csv("본선용 데이터/rmse_nrmse_summary_all_etfs(vty_z_sor_100).csv", fileEncoding = "CP949", row.names = NULL)

# 히스토그램 생성 및 색상과 x축 레이블 지정
x11();hist(vty_z_sor_100_RMSE$Test.RMSE,  # 히스토그램 색상
           xlab = "vty_z_sor_100_RMSE Test RMSE Values",  # x축 레이블
           main = "")  # 그래프 제목 (필요에 따라 변경 가능)

# RMSE가 5 이하인 값의 개수 세기
count_rmse_below_5 <- sum(vty_z_sor_100_RMSE$Test.RMSE <= 5, na.rm = TRUE)
print(count_rmse_below_5)

