# 소셜네트워크 분석 

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import networkx as nx
import re
from collections import Counter

# 파일 경로
file_path = "C:/Users/user/Desktop/nh/nhpro/cleaned/etfc8c.txt"

# 파일 읽기
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

# 데이터 전처리: 단어 리스트 생성
words = re.findall(r'\b\w+\b', text)  # 단어 추출 (정규 표현식 사용)
word_counts = Counter(words)  # 단어 빈도 계산

# 동시 출현 빈도 저장 dict
count = {}
for i in range(len(words)):
    for j in range(i + 1, len(words)):
        if words[i] != words[j]:  # 서로 다른 단어들만
            if (words[i], words[j]) not in count:
                count[(words[i], words[j])] = 1
            else:
                count[(words[i], words[j])] += 1

# DataFrame으로 변환
df = pd.DataFrame.from_dict(count, orient='index', columns=['freq'])
df.reset_index(inplace=True)
df[['term1', 'term2']] = pd.DataFrame(df['index'].tolist(), index=df.index)
df.drop(columns=['index'], inplace=True)
df = df.sort_values(by='freq', ascending=False)

# 네트워크 생성
G = nx.Graph()

# 빈도수 3 이상인 단어쌍에 대해서만 edge 표현
for index, row in df.iterrows():
    if row['freq'] >= 3:
        G.add_edge(row['term1'], row['term2'], weight=row['freq'])

# 노드 크기 조정 (연결 정도를 기준으로 크기를 조정)
sizes = [G.degree(node) * 200 for node in G]  # 크기 조정
# 중심 노드의 색상 변경
colors = ['black' if G.degree(node) < 3 else 'orange' for node in G]

# 네트워크 시각화
plt.figure(figsize=(12, 8))
pos = nx.spring_layout(G, k=0.2, iterations=20)  # 레이아웃 조정
nx.draw_networkx_nodes(G, pos, node_size=sizes, alpha=0.9, node_color=colors)  # 노드 색상 및 투명도 조정
nx.draw_networkx_edges(G, pos, width=1.5, alpha=0.5)  # 엣지 두께 조정
nx.draw_networkx_labels(G, pos, font_size=10, font_family='Malgun Gothic', font_color='black')  # 레이블 조정

plt.title('소셜 네트워크 분석 결과')
plt.axis('off')  # 축 제거
plt.show()

# 중심성 척도 계산

import pandas as pd
import networkx as nx

# G = nx.Graph()
# [G에 노드 및 엣지 추가]

# 중심성 척도값 계산
degree = dict(G.degree())
betweenness = nx.betweenness_centrality(G)
closeness = nx.closeness_centrality(G)
eigenvector = nx.eigenvector_centrality(G)
pagerank = nx.pagerank(G)

# 중심성 척도값을 DataFrame으로 변환
centrality_data = {
    'keyword': list(degree.keys()),
    'degree': list(degree.values()),
    'betweenness': [betweenness[key] for key in degree.keys()],
    'closeness': [closeness[key] for key in degree.keys()],
    'eigenvector': [eigenvector[key] for key in degree.keys()],
    'pagerank': [pagerank[key] for key in degree.keys()],
}

centrality_df = pd.DataFrame(centrality_data)

# DataFrame을 CSV 파일로 저장
centrality_df.to_csv('scetf8ccc.csv', index=False, encoding='utf-8-sig')

# 네트워크 행렬 만들기
adj_matrix = nx.adjacency_matrix(G).todense()  # G는 생성한 NetworkX 그래프
nodes = list(G.nodes())

# 인접 행렬을 DataFrame으로 변환
adj_df = pd.DataFrame(adj_matrix, index=nodes, columns=nodes)

# 인접 행렬 출력
print(adj_df)

# CSV로 저장
adj_df.to_csv('network_adjacency_matrix.csv', encoding='utf-8-sig')
