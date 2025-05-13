import pandas as pd
import re
from collections import Counter

file_path2 = "../ETF/HDATA/etfc8c.txt"
# 파일 읽기
with open(file_path2, 'r', encoding='utf-8') as f2:
    text2 = f2.read()

# 유의어 사전
synonym_dict = {
    "엔비": "엔비디아",
    "디아": "엔비디아",
    "비디": "엔비디아"
}

# 제거할 단어 목록
words_to_remove = [
    "투자", "자료", "증권", "리서치", "본부", "종목", "월간", "이후", "지난해",
    "나머지", "전년", "해자", "비교", "과거", "기간", "기존", "고려", "데일리",
    "포함", "예년", "측면", "단기", "기준", "연초", "경우", "연내", "동안",
    "주식", "미국", "한국", "글로벌", "비중", "등급", "전망", "지수"
]

# 유의어 치환 함수
def replace_synonyms(text, synonym_dict):
    for fragment, full_word in synonym_dict.items():
        text = re.sub(r'\b' + re.escape(fragment) + r'\b', full_word, text)
    return text

# 특정 단어 제거 함수
def remove_words(text, words_to_remove):
    for word in words_to_remove:
        text = re.sub(r'\b' + re.escape(word) + r'\b', '', text)
    return text

# 단어 처리 함수
def process_words(text):
    # 유의어 치환 적용
    text = replace_synonyms(text, synonym_dict)

    # 특정 단어 제거 적용
    text = remove_words(text, words_to_remove)

    # '높'과 '낮'을 각각 '높다'와 '낮다'로 변환
    text = re.sub(r'\b높\b', '높다', text)
    text = re.sub(r'\b낮\b', '낮다', text)

    # 한 글자 단어 제거 (단 '금'은 남김)
    text = re.sub(r'\b(?!금)\w{1}\b', '', text)

    # 소수점이 있는 숫자 제거 (예: .18, 1.23 등)
    text = re.sub(r'\b\d*\.?\d+\b', '', text)

    # 불필요한 공백 제거
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text

# 처리된 텍스트
processed_text = process_words(text2)

# 단어 리스트 생성
words = processed_text.split()

# 단어 빈도 계산
word_counts = Counter(words)

# DataFrame으로 변환
df = pd.DataFrame(word_counts.items(), columns=['단어', '빈도수'])

# 빈도수로 정렬
df = df.sort_values(by='빈도수', ascending=False).reset_index(drop=True)

# 감정 분석을 위한 단어 목록 로드
positive_df = pd.read_excel("../ETF/EFSD-main/EFSD_pos_word.xlsx")
positive_words = positive_df[positive_df['label'] == 1]['word'].tolist()

# 부정 단어 목록을 엑셀 파일에서 불러오기 (라벨이 -1인 경우 부정 단어로 가정)
negative_df = pd.read_excel("../ETF/EFSD-main/EFSD_neg_word.xlsx")
negative_words = negative_df[negative_df['label'] == -1]['word'].tolist()

# 단어의 감정을 결정하는 함수
def analyze_sentiment(word, pos_words, neg_words):
    if word in pos_words:
        return 'Positive'
    elif word in neg_words:
        return 'Negative'
    else:
        return 'Neutral'

# 빈도 분석한 단어들에 대해 감정 분석 수행
sentiment_results = []
for word, freq in word_counts.most_common():
    sentiment = analyze_sentiment(word, positive_words, negative_words)
    sentiment_results.append({'Word': word, 'Frequency': freq, 'Sentiment': sentiment})

# 결과를 데이터프레임으로 변환
senti_df = pd.DataFrame(sentiment_results)

# 전체 데이터프레임 출력 설정
pd.set_option('display.max_rows', None)

# 결과 출력
print(senti_df)

import matplotlib.pyplot as plt
import pandas as pd

# 긍정 단어와 부정 단어를 필터링
positive_df = senti_df[senti_df['Sentiment'] == 'Positive'].sort_values(by='Frequency', ascending=False).head(10)
negative_df = senti_df[senti_df['Sentiment'] == 'Negative'].sort_values(by='Frequency', ascending=False).head(10)

# 긍정 단어 빈도 그래프 그리기
plt.figure(figsize=(10, 5))
plt.barh(positive_df['Word'], positive_df['Frequency'], color='blue')
plt.xlabel('Frequency')
plt.ylabel('Positive Words')
plt.title('Top Positive Words by Frequency')
plt.gca().invert_yaxis()  # y축을 역순으로 표시
plt.show()

# 부정 단어 빈도 그래프 그리기
plt.figure(figsize=(10, 5))
plt.barh(negative_df['Word'], negative_df['Frequency'], color='red')
plt.xlabel('Frequency')
plt.ylabel('Negative Words')
plt.title('Top Negative Words by Frequency')
plt.gca().invert_yaxis()  # y축을 역순으로 표시
plt.show()