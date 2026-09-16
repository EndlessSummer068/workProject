# 爬虫数据处理与可视化（spider_project）

## 项目简介
本项目包含两个数据采集与可视化子项目：豆瓣电影 Top250 爬虫和古诗词网 1000 首爬虫，均使用 requests + BeautifulSoup 采集数据，使用 pandas 完成清洗，并通过 matplotlib/seaborn/Streamlit 完成数据分析与可视化展示。

## 技术栈
- Python、requests、BeautifulSoup
- pandas、numpy、openpyxl（数据清洗与存储）
- scipy、scikit-learn（数据分析）
- matplotlib、seaborn、wordcloud、jieba、squarify、plotly（数据可视化）
- Streamlit、Flask（Web 仪表盘展示）

## 功能说明
- 豆瓣电影 Top250：爬取电影名、别名、导演、演员、年份、国家、类型、评分、评价人数与简介，分页拉取并处理重试、随机延迟与状态码校验
- 古诗词网 1000 首：爬取标题、作者、朝代、正文、URL、标签，配置化分页采集 `gushici-box` 条目
- 数据清洗：对原始 CSV 进行去重、缺失值处理，输出清洗后的 CSV/Excel
- 数据分析：电影评分统计、古诗词朝代/作者/标签/字数分布分析
- 数据可视化：柱状图、饼图、词云、矩形树图等 PNG 输出，并集成 Streamlit 概览页（诗词总数、朝代、作者、标签、字数等核心指标）
- 端到端流程：`spider.py → cleaner.py → analyzer.py → app.py`

## 如何运行
1. 安装依赖
   ```bash
   cd spider_project
   python -m venv venv
   venv\Scripts\activate
   pip install -r gushici_spider/requirements.txt
   ```
2. 豆瓣 Top250 流程
   ```bash
   cd douban_spider
   python spiders/douban_spider.py    # 采集原始数据
   python data_processing/cleaner.py  # 清洗数据
   python data_processing/analyzer.py # 分析与可视化
   ```
3. 古诗词流程
   ```bash
   cd gushici_spider
   python spiders/spider.py           # 采集 1000 首诗词
   python data_processing/cleaner.py  # 清洗
   python data_processing/analyzer.py # 可视化输出
   streamlit run app.py               # 启动 Web 仪表盘
   ```

## 关键文件
- 豆瓣爬虫入口：[douban_spider/spiders/douban_spider.py](file:///d:/pythonProject/spider_project/douban_spider/spiders/douban_spider.py)
- 豆瓣清洗器：[douban_spider/data_processing/cleaner.py](file:///d:/pythonProject/spider_project/douban_spider/data_processing/cleaner.py)
- 豆瓣分析器：[douban_spider/data_processing/analyzer.py](file:///d:/pythonProject/spider_project/douban_spider/data_processing/analyzer.py)
- 古诗词爬虫：[gushici_spider/spiders/spider.py](file:///d:/pythonProject/spider_project/gushici_spider/spiders/spider.py)
- 古诗词清洗器：[gushici_spider/data_processing/cleaner.py](file:///d:/pythonProject/spider_project/gushici_spider/data_processing/cleaner.py)
- 古诗词分析器：[gushici_spider/data_processing/analyzer.py](file:///d:/pythonProject/spider_project/gushici_spider/data_processing/analyzer.py)
- 古诗词 Streamlit 仪表盘：[gushici_spider/app.py](file:///d:/pythonProject/spider_project/gushici_spider/app.py)
- 依赖清单：[gushici_spider/requirements.txt](file:///d:/pythonProject/spider_project/gushici_spider/requirements.txt)
