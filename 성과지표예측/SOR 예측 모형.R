# 패키지 로드
library(dplyr)
library(VIM)
library(ggplot2)
library(zoo)
library(tidyr)
library(caret)
library(glmnet)
library(car)
library(corrplot)
library(forecast)
library(Metrics)
library(keras3) 
library(tibble)
library(reticulate)
#install_keras(method = "conda", tensorflow = "2.8.0")
#install.packages("kerastuneR")
library(kerastuneR)
#install.packages("tfdatasets")
library(tfdatasets)
#reticulate::py_install("keras-tuner", pip = TRUE)
library(kerastuneR)


setwd("C:/Users/funch/OneDrive/바탕 화면/고려대/2024/2학기/취뽀공주/NH투자증권 ETF 경진대회 본선/본선용 데이터/open_본선데이터/")
DD_data <- read.csv("NH_CONTEST_NHDATA_STK_DD_IFO.csv", fileEncoding = "CP949", row.names = NULL)
DT_data <- read.csv("NH_CONTEST_STK_DT_QUT.csv", fileEncoding = "CP949", row.names = NULL)

#inner join 
DD_DT.merged_data <-  merge(DT_data, DD_data, by = c("bse_dt", "tck_iem_cd"))
head(DD_DT.merged_data)

nrow(DD_DT.merged_data) #77794
nrow(DD_data) #81638
nrow(DT_data) #290890

colnames(DD_DT.merged_data) #bse_dt, tck_iem_cd

##################################################################################
#섹터명 붙이기
##################################################################################
#섹터분류가 포함된 데이터 불러오기
sector_data <- read.csv("NH_CONTEST_NW_FC_STK_IEM_IFO.csv", fileEncoding = "CP949", row.names = NULL)

#DD_DT.merged_data$tck_iem_cd의 공백 제거: 매칭을 위한 형식 통일
DD_DT.merged_data$tck_iem_cd <- trimws(as.character(DD_DT.merged_data$tck_iem_cd))

DD_DT.merged_data <- DD_DT.merged_data %>%
  mutate(ser_cfc_nm = sector_data$ser_cfc_nm[match(tck_iem_cd, sector_data$tck_iem_cd)])

head(DD_DT.merged_data)
nrow(DD_DT.merged_data)
ncol(DD_DT.merged_data)
#결측데이터 확인
table(DD_DT.merged_data$ser_cfc_nm) #-: 10233, Basic Materials: 2562 ,...
sum(is.na(DD_DT.merged_data$ser_cfc_nm)) #0

##################################################################################
#대상 ETF 티커에 ETF 개별 구성 종목 티커와 보유 종목의 비중을 합친 데이터 셋 생성
##################################################################################
#holdings와 score 데이터 불러오기
holdings_data <- read.csv("NH_CONTEST_DATA_ETF_HOLDINGS.csv", fileEncoding = "CP949", row.names = NULL)
colnames(holdings_data) #etf_tck_cd, tck_iem_cd, wht_pct

sor_data <- read.csv("NH_CONTEST_ETF_SOR_IFO.csv", fileEncoding = "CP949", row.names = NULL)
colnames(sor_data) #bse_dt, etf_iem_cd

#sor_data$etf_iem_cd 공백 제거: 매칭을 위한 형식 통일
sor_data$etf_iem_cd <- trimws(as.character(sor_data$etf_iem_cd))


# holdings_data와 sor_data를 etf_iem_cd(=etf_tck_cd)를 기준으로 병합
sor_holdings.merged_data <- sor_data %>%
  inner_join(holdings_data, by = c("etf_iem_cd" = "etf_tck_cd"),relationship = "many-to-many")

#데이터 확인하기
head(sor_holdings.merged_data)
nrow(sor_holdings.merged_data) #5991809
sum(is.na(sor_holdings.merged_data$sec_tp)) #1798
sum(is.na(sor_holdings.merged_data$tck_iem_cd)) #1798
length(unique(sor_holdings.merged_data$etf_iem_cd)) #341

#데이터 순서 정렬하기

##################################################################################
#merge: sor_holdings.merged_data와 DD_DT.merged_data
##################################################################################
colnames(sor_holdings.merged_data) #bse_dt, etf_iem_cd, tck_iem_cd
colnames(DD_DT.merged_data) #bse_dt, tck_iem_cd

merged_data <- sor_holdings.merged_data %>%
  inner_join(DD_DT.merged_data, by = c("bse_dt", "tck_iem_cd"), relationship = "many-to-many")

#데이터확인하기
nrow(merged_data)#2643113
length(unique(merged_data$etf_iem_cd)) #337
table(merged_data$ser_cfc_nm) #-: 9547
colnames(merged_data)

##################################################################################
#변수 제외
#fc_sec_eng_nm: 외화증권한글명
#fc_sec_krl_nm: 외화증권영문명
#stk_qty: 보유종목의 주수(보유 종목의 비중(%)을 사용하기 때문에 제외함)
#sec_tp:보유 종목의 타입 (ST: 주식, EF: ETF, EN: ETN, SSEF: Single-Stock ETF)
##################################################################################
data <- merged_data %>%
  select(-fc_sec_eng_nm, -fc_sec_krl_nm, -stk_qty, -sec_tp) %>%  # 열 제거
  select(bse_dt, etf_iem_cd, tck_iem_cd, wht_pct, ser_cfc_nm, everything())  # 열 순서 변경

#write.csv(data, "데이터 머지/rawdata for score predicion model.csv", row.names = FALSE, fileEncoding = "UTF-8")
ncol(data)
colnames(data)
##################################################################################
#ETF의 섹터를 구분하기
#기본 아이디어는 주식티커의 구성비율이 큰 걸 따라가자
#ETF에서 섹터를 그룹하고 섹터별로 구성비율을 합한다.
#그중 높은 구성비율인 것의 섹터를 ETF의 섹터라고 한다.
##################################################################################

# 1. 데이터 추출 및 중복 제거
unique_data <- data %>%
  select(etf_iem_cd, tck_iem_cd, wht_pct, ser_cfc_nm) %>%
  distinct()

head(unique_data)

# 2. ETF별로 섹터별 그룹화하고, 구성비율 합산 (etf_sector_wht_pct 생성)
etf_sector_wht_pct <- unique_data %>%
  group_by(etf_iem_cd, ser_cfc_nm) %>%
  summarise(total_wht_pct = sum(wht_pct, na.rm = TRUE), .groups = "drop")  # 그룹 해제

head(etf_sector_wht_pct)

# 3. 각 ETF별로 가장 높은 total_wht_pct를 찾고, 그 값의 5% 이내의 섹터를 찾기
etf_sector_wht_pct_with_diff <- etf_sector_wht_pct %>%
  group_by(etf_iem_cd) %>%
  mutate(max_wht_pct = max(total_wht_pct, na.rm = TRUE)) %>%
  filter(total_wht_pct >= (max_wht_pct - max_wht_pct * 0.05)) %>%
  distinct(etf_iem_cd, ser_cfc_nm, .keep_all = TRUE) %>%
  ungroup()

# 4. 동일 ETF 내 섹터를 문자열로 연결하기 (reframe 사용)
etf_sector_summary <- etf_sector_wht_pct_with_diff %>%
  group_by(etf_iem_cd) %>%
  reframe(
    sector_list = case_when(
      n() == 2 ~ paste(ser_cfc_nm, collapse = " and "),
      n() > 2 ~ paste0(paste(head(ser_cfc_nm, -1), collapse = ", "), ", and ", tail(ser_cfc_nm, 1)),
      TRUE ~ ser_cfc_nm
    )
  )

head(etf_sector_summary)

# 5. 원래 data에 etf_sector_summary의 섹터 명을 etf_sector_nm으로 추가 (left_join 사용)
data <- data %>%
  left_join(etf_sector_summary, by = "etf_iem_cd", relationship = "many-to-many") %>% 
  rename(etf_sector_nm = sector_list)                  

data <- data %>% # 데이터 순서정렬
  select(bse_dt, etf_iem_cd, etf_sector_nm, tck_iem_cd, wht_pct, ser_cfc_nm, everything())  # 열 순서 변경

# 데이터확인
print(head(data))
sum(is.na(data$etf_sector_nm)) #0
table(data$etf_sector_nm) #-: 14209

##################################################################################
#티커 정보에 가중치를 부여하여 ETF에 대한 데이터로 만들기
##################################################################################
#퍼센트를 백분율로 변경
# 1. etf_iem_cd, bse_dt, wht_pct와 sor데이터 변수를 제외한 나머지 변수 선택
head(data)
weighted_data <- data %>%
  select(-c(3:4,6:19))  # a, b, c 변수 제외

# 2. 가중치 적용: etf_iem_cd, bse_dt는 제외하고, 나머지 변수에만 가중치 곱하기
result_data <- weighted_data %>%
  mutate(across(-c(etf_iem_cd, bse_dt, wht_pct), ~ . * wht_pct, .names = "weighted_{col}")) %>%
  group_by(bse_dt, etf_iem_cd) %>%
  summarise(across(starts_with("weighted_"), sum, na.rm = TRUE),  # 가중치를 곱한 후 합산
            total_wht_pct = sum(wht_pct, na.rm = TRUE), 
            .groups = "drop") %>%  # 그룹 해제
  mutate(across(starts_with("w_"), ~ . / total_wht_pct, .names = "{col}_final")) %>%
  select(-total_wht_pct) %>%  # 가중치(wht_pct)와 중간 계산값 제거
  ungroup()

# 결과 확인
head(result_data)

# 아까 빼놓은 데이터 합치기
# 1. 원래 데이터에서 필요한 열(1:4, 6:19)만 선택
additional_data <- data %>%
  select(c(1:3, 7:19)) %>%
  distinct()# 변수 번호로 선택

# 2. result_data와 additional_data를 etf_iem_cd와 bse_dt를 기준으로 병합
final_data <- result_data %>%
  left_join(additional_data, by = c("etf_iem_cd", "bse_dt"))%>%
  select(bse_dt, etf_iem_cd, etf_sector_nm, etf_sector_nm, everything()) 

# 결과 확인
head(final_data)
table(final_data$etf_sector_nm)

##################################################################################
#etf_sector_nm에서 -로 구분되지 않은 섹터확인하기 = 전체를 의미
##################################################################################
data <- final_data

#-인 ETF의 개수 확인하기 
a<- as.data.frame(unique(data[,c("etf_iem_cd","etf_sector_nm")]))
table(a$etf_sector_nm) #7개가 - 로 확인

# 1. etf_sector_nm이 "-"인 ETF명 필터링
etf_with_dash <- a %>%
  filter(etf_sector_nm == "-")

# 2. 결과 확인 (ETF명 출력)
print(etf_with_dash) #FYLG, KLIP, RSST, SMMD, SPBC, SPYC, YMAG

##################################################################################
#결측확인: 비어있는 날짜 확인
##################################################################################
data
#data$bse_dt <- as.numeric(data$bse_dt) #날짜가 아닌 숫자로 인식되게 하기 위한 

# 히트맵 그리기

# 1. 날짜(bse_dt)와 ETF 코드(etf_iem_cd)로 데이터를 정렬
result_data <- data %>%
  arrange(etf_iem_cd, bse_dt)

# 2. 모든 ETF와 날짜 조합 생성
all_combinations <- expand.grid(
  bse_dt = unique(result_data$bse_dt),  # 모든 날짜
  etf_iem_cd = unique(result_data$etf_iem_cd)  # 모든 ETF 코드
)

# 3. 원본 데이터와 모든 가능한 조합을 병합하여, 누락된 값을 NA로 처리
result_data_full <- all_combinations %>%
  left_join(result_data, by = c("bse_dt", "etf_iem_cd"))

# 4. 날짜 대신 인덱스를 생성 (날짜 간격을 고려하지 않기 위함)
result_data_full <- result_data_full %>%
  mutate(date_index = as.numeric(factor(bse_dt)))  # 날짜를 단순히 인덱스로 변환

# 5. 히트맵 그리기 (x축은 인덱스, y축은 etf_iem_cd, 색상은 NA 여부)
x11();ggplot(result_data_full, aes(x = date_index, y = etf_iem_cd, fill = is.na(etf_z_sor))) + 
  geom_tile() +  # 히트맵 타일
  scale_fill_manual(values = c("TRUE" = "#F6EBDF", "FALSE" = "black"), 
                    name = "Missing Data", labels = c("No", "Yes")) +  # 결측값 여부에 따라 색상 지정
  labs(title = "Missing Dates in ETF Data (No Date Gaps)", x = "Date Index", y = "ETF Code") + 
  theme_minimal() +  # 미니멀한 테마
  theme(axis.text.x = element_text(angle = 90, hjust = 1),  # x축 텍스트 회전
        axis.text.y = element_blank(),  # y축 텍스트 제거
        axis.ticks.y = element_blank())  # y축 틱 제거

# 6. 결측값이 있는 ETF 이름 필터링 (etf_z_sor에서 결측값 확인)
missing_etf_names <- result_data_full %>%
  filter(is.na(etf_z_sor)) %>%
  distinct(etf_iem_cd)  # 중복 제거 후 결측값이 있는 ETF 코드만 추출

# 7. 결측값이 있는 ETF만 필터링하여 데이터를 준비
result_data_missing <- result_data_full %>%
  filter(etf_iem_cd %in% missing_etf_names$etf_iem_cd)  # 결측값이 있는 ETF만 필터링

# 8. x축의 bse_dt를 factor로 변환 (시간 간격을 무시하면서 날짜를 그대로 표시)
result_data_missing <- result_data_missing %>%
  arrange(bse_dt) %>%  # 날짜 정렬 후
  mutate(bse_dt_factor = factor(bse_dt))  # 날짜를 factor로 변환하여 간격을 무시

# 9. 히트맵 그리기 (결측값이 있는 ETF만 Y축에 표시, etf_z_sor 기준)
x11();ggplot(result_data_missing, aes(x = bse_dt_factor, y = etf_iem_cd, fill = is.na(etf_z_sor))) + 
  geom_tile() +  # 히트맵 타일
  scale_fill_manual(values = c("TRUE" = "#F6EBDF", "FALSE" = "black"), 
                    name = "Missing Data", labels = c("No", "Yes")) +  # 결측값 여부에 따라 색상
  labs(title = "Missing Dates by ETF (Only Missing ETFs, etf_z_sor)", x = "Date", y = "ETF Code") + 
  theme_minimal() +  # 미니멀한 테마
  theme(axis.text.x = element_text(angle = 90, hjust = 1))  # x축 날짜 텍스트 회전

table(data$bse_dt) #6월 28일, ETF 46개 결측

#결측데이터는 6월 28일과 YMAG와 IQQQ
#6월 28일은 보간을 고려하고, YMAG와 IQQQ는 제거를 고려함
###########################################################################
# 1. YMAG와 IQQQ를 일단 삭제하고 나머지 변수에 대해 모델을 고려함

# YMAG와 IQQQ를 제외한 나머지 데이터를 필터링
data_filtered <- data %>%
  filter(!etf_iem_cd %in% c("YMAG", "IQQQ"))

# 결과 확인
head(data_filtered)
data <- data_filtered
###########################################################################
# 2. 6월 28일에 대한 스플라인 보간을 수행함
data_spline <- data
data_spline$bse_dt <- as.Date(as.character(data_spline$bse_dt), format = "%Y%m%d")
target_date <- as.Date("2024-06-28")

# 1. 각 etf_iem_cd 그룹에 대해 2024-06-28이 존재하지 않으면 해당 날짜의 행을 추가
data_with_missing <- data_spline %>%
  group_by(etf_iem_cd, etf_sector_nm) %>%
  # 그룹 내에서 2024-06-28이 없는 경우에만 추가
  filter(!target_date %in% bse_dt) %>%
  summarise(bse_dt = target_date, .groups = 'drop') %>%
  # 원래 데이터와 결합
  bind_rows(data_spline) %>%
  arrange(etf_iem_cd, bse_dt)

# 2. 스플라인 보간을 사용하여 NA 값을 6월 28일에 대해 보간
data_with_spline <- data_with_missing %>%
  group_by(etf_iem_cd) %>%
  mutate(across(
    where(is.numeric), 
    ~ ifelse(bse_dt == target_date & is.na(.), na.spline(.), .)
  )) %>%
  ungroup()

head(data_with_spline)

# 결과 확인 (2024-06-28에 대한 데이터 확인)
(a <- data_with_spline %>% filter(bse_dt == as.integer(target_date)))
print(data_with_spline %>% filter(bse_dt == as.integer(target_date)))
data <- data_with_spline
###########################################################################
#값이 0으로 차있는 결측치 처리 => 삭제 처리함, 이유 예측 데이터가 아예존재하지 않음
###########################################################################
data_zero_weighted_mkt_vlu <- data %>%
  filter(weighted_mkt_vlu == 0)

# 추출된 데이터 확인
print(data_zero_weighted_mkt_vlu) #: RYLD

# RYLD인 행을 모두 삭제
data <- data %>%
  filter(etf_iem_cd != "RYLD       ")

# 결과 확인
print(data)


###########################################################################
#다시 결측치를 확인함
###########################################################################
# 1. x축의 bse_dt를 factor로 변환 (시간 간격을 무시하면서 날짜를 그대로 표시)
check_data_missing <- data %>%
  arrange(bse_dt) %>%  # 날짜 정렬 후
  mutate(bse_dt_factor = factor(bse_dt))  # 날짜를 factor로 변환하여 간격을 무시

# 2. 히트맵 그리기 (결측값이 있는 ETF만 Y축에 표시, etf_z_sor 기준)
# X축 라벨을 제거한 히트맵
x11();ggplot(check_data_missing, aes(x = bse_dt_factor, y = etf_iem_cd, fill = is.na(etf_z_sor))) + 
  geom_tile() +  # 히트맵 타일
  scale_fill_manual(values = c("TRUE" = "#F6EBDF", "FALSE" = "black"), 
                    name = "Missing Data", labels = c("No", "Yes")) +  # 결측값 여부에 따라 색상
  labs(title = "Missing Dates by ETF (Only Missing ETFs, etf_z_sor)", x = "Date", y = "ETF Code") + 
  theme_minimal() +  # 미니멀한 테마
  theme(axis.text.y = element_blank(),  # Y축 텍스트 완전히 제거
        axis.title.y = element_text(),
        axis.text.x = element_blank(),  # Y축 텍스트 완전히 제거
        axis.title.x = element_text())  # Y축 제목을 보이도록 설정


#write.csv(data, file = "data_with_spline.csv", row.names = FALSE)

###########################################################################
#데이터 표준화
###########################################################################
# 데이터 준비 
setwd("C:/Users/funch/OneDrive/바탕 화면/고려대/2024/2학기/취뽀공주/NH투자증권 ETF 경진대회 본선/본선용 데이터/open_본선데이터/")
data <- read.csv("data_with_spline.csv", fileEncoding = "CP949", row.names = NULL)

stadard_data <- data  # 표준화할 원래 데이터

# 'weighted'가 포함된 변수만 선택하여 numeric_data 생성
numeric_data <- stadard_data %>%
  select(contains("weighted", ignore.case = TRUE))
colnames(numeric_data)

# 나머지 'weighted'가 포함되지 않은 변수 선택
remaining_data <- stadard_data %>%
  select(-contains("weighted", ignore.case = TRUE))
colnames(remaining_data)

# Min-Max 스케일러 생성 및 적용
scaler <- preProcess(numeric_data, method = "range")
minmax_scaled_numeric_data <- predict(scaler, numeric_data)

# 원래 데이터 구조로 결합
final_data <- cbind(remaining_data, minmax_scaled_numeric_data)

# 결과 확인
print(final_data)
#write.csv(final_data, file = "(minmixscaled)data_with_spline.csv", row.names = FALSE)

###########################################################################
#회귀모델
###########################################################################
setwd("C:/Users/funch/OneDrive/바탕 화면/고려대/2024/2학기/취뽀공주/NH투자증권 ETF 경진대회 본선/본선용 데이터/open_본선데이터/")
final_data <- read.csv("(minmixscaled)data_with_spline.csv", fileEncoding = "CP949", row.names = NULL)
final_data <- final_data %>%
  select(-weighted_mkt_vlu)

data <- final_data

# 'weighted'가 포함된 변수만 선택
weighted_vars <- data %>%
  select(contains("weighted", ignore.case = TRUE))

# 변수 이름 가져오기
(weighted_var_names <- colnames(weighted_vars))

# 회귀 모델 공식 생성
formula <- as.formula(paste("etf_sor ~", paste(weighted_var_names, collapse = " + ")))

# 회귀 모델 적합=> 유의함
summary(lm(formula, data = lm_data))

###########################################################################
#종속변수(score점수)이 상관성 확인
###########################################################################
score <- data %>%
  select(-etf_iem_cd, -etf_sector_nm, -bse_dt, -starts_with("weighted_"))

# 히트맵 생성
cor_matrix <- cor(score, use = "complete.obs")
x11();corrplot(cor_matrix, method = "color", type = "lower", tl.col = "black", tl.srt = 45,
         addCoef.col = "black", number.cex = 0.7)

#종속변수 선택: etf_sor(ETF점수), crr_z_sor(상관관계Z점수), trk_err_z_sor(트래킹에러Z점수), 
#mxdd_z_sor(최대낙폭Z점수), vty_z_sor(변동성Z점수), mm1_tot_pft_rt(1개월총수익율), 
#mm3_tot_pft_rt(3개월총수익율), yr1_tot_pft_rt(1년총수익율) 만 선택
score <- score %>%
  select(etf_sor, crr_z_sor, mxdd_z_sor, vty_z_sor, mm1_tot_pft_rt, mm3_tot_pft_rt, yr1_tot_pft_rt)

#비율에 대한 것을 제외하고 z점수에 대한 것을 100점을 기준으로 만들기
variables_to_scale <- c("etf_sor", "crr_z_sor", "trk_err_z_sor", "mxdd_z_sor", "vty_z_sor")

for (var in variables_to_scale) {
  scaler <- preProcess(data.frame(value = score[[var]]), method = c("range"), rangeBounds = c(1, 100))
  score[[paste0(var, "_100")]] <- predict(scaler, data.frame(value = score[[var]]))$value
}

# 결과 데이터 프레임 확인
head(score)
summary(score$etf_sor_100)
summary(score$crr_z_sor_100)
summary(score$trk_err_z_sor_100)
summary(score$mxdd_z_sor_100)
summary(score$vty_z_sor_100)

a <- cbind(etf_iem_cd=data$etf_iem_cd, etf_sector_nm=data$etf_sector_nm, bse_dt=data$bse_dt, weighted_vars, score)
#write.csv(a, file = "score백분위, min-max scaling 포함 데이터.csv", row.names = FALSE)



setwd("C:/Users/funch/OneDrive/바탕 화면/고려대/2024/2학기/취뽀공주/NH투자증권 ETF 경진대회 본선/본선용 데이터/open_본선데이터/")
A <- read.csv("rmse_nrmse_summary_all_etfs(vty_z_sor_100).csv", fileEncoding = "CP949", row.names = NULL)
head(A)
hist(A$Test.RMSE)
sum(A$Test.RMSE <= 5, na.rm = TRUE)

B <- read.csv("rmse_nrmse_summary_all_etfs(crr_z_sor_100).csv", fileEncoding = "CP949", row.names = NULL)
head(B)
x11();hist(B$Test.RMSE, breaks=seq(0, 100), by=5)
sum(B$Test.RMSE <= 5, na.rm = TRUE)

C <- read.csv("rmse_nrmse_summary_all_etfs(mxdd_z_sor).csv", fileEncoding = "CP949", row.names = NULL)
head(C)
hist(C$Test.RMSE)
sum(C$Test.RMSE <= 5, na.rm = TRUE)


D <- read.csv("rmse_nrmse_summary_all_etfs(mm1_tot_pft_rt).csv", fileEncoding = "CP949", row.names = NULL)
head(D)
hist(D$Test.RMSE)
sum(D$Test.RMSE <= 5, na.rm = TRUE)

E <- read.csv("rmse_nrmse_summary_all_etfs(mm3_tot_pft_rt).csv", fileEncoding = "CP949", row.names = NULL)
head(E)
hist(E$Test.RMSE)
sum(E$Test.RMSE <= 5, na.rm = TRUE)


A <- read.csv("rmse_nrmse_summary_all_etfs.csv", fileEncoding = "CP949", row.names = NULL)
head(A)
hist(A$Test.RMSE)
sum(A$Test.RMSE <= 5, na.rm = TRUE)
