import streamlit as st
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
# 忽略Python运行时，产生的所有警告信息，让输出更简洁
warnings.filterwarnings('ignore')
from pathlib import Path
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 导入自定义模块
try:
    from data_processing.cleaner import DouBanCleaner
    from data_processing.analyzer import DouBanAnalyzer,setup_chinese_font
    from spiders.douban_spider import DoubanMovieSpider,Config
except ImportError as e:
    st.error(f"导入模块失败: {e}")
    st.info("请确保项目结构正确，且已安装所有依赖")

# 美化Streamlit应用的界面
st.markdown("""
    <style>
    .main-header {  
        font-size: 2.5rem;
        color: #2E86AB;
        text-align: center;
        margin-bottom: 1rem;
    }
    .section-header {
        font-size: 1.8rem;
        color: #A23B72;
        margin-top: 2rem;
        margin-bottom: 1rem;
        border-bottom: 2px solid #F18F01;
        padding-bottom: 0.5rem;
    }
    .metric-card {
        background-color: #f8f9fa;
        border-radius: 10px;
        padding: 1rem;
        text-align: center;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .metric-value {
        font-size: 2rem;
        font-weight: bold;
        color: #2E86AB;
    }
    .metric-label {
        font-size: 0.9rem;
        color: #6c757d;
    }
    .movie-card {
        background-color: #fff;
        border-radius: 10px;
        padding: 1rem;
        margin-bottom: 1rem;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        border-left: 4px solid #F18F01;
    }
</style>
""", unsafe_allow_html=True)   # 允许在Streamlit中渲染

class DouBanDashBoard:
    def __init__(self):
        self.analyzer = DouBanAnalyzer()
        self.df = None
        self.stats = None

    # 加载数据
    def load_data(self):
        if self.analyzer.load_data():
            # 将分析器中数据框，赋值给当前实例
            self.df = self.analyzer.df
            # 计算并保存基本统计数据
            self.stats = self.analyzer.basic_statistics()
            # 加载成功返回True
            return True
        return False

    """显示概览页面"""
    def show_overview(self):
        st.markdown(
            '<h1 class="main-header">🎬 豆瓣电影Top250数据分析</h1>', unsafe_allow_html=True
        )
        # 简介
        st.markdown("""
                ### 项目简介
                本项目对豆瓣电影Top250榜单进行全面的数据分析，包括：
                - 🎥 **电影信息统计**：导演、演员、类型、国家地区分布
                - ⭐ **评分分析**：评分分布、趋势、相关性
                - 📊 **可视化图表**：多种图表展示数据洞察
                - 🔍 **深度挖掘**：时间趋势、热门分析、质量评估

                使用左侧导航菜单切换不同功能模块。
            """)
        # 在Streamlit页面，插入一条水平分隔线,用于区分不同的内容区块
        st.divider()

        # 检查数据是否成功加载
        if self.df is not None:  # 检查数据框是否存在
            # 如果数据已加载,显示摘要指标卡片
            self.show_summary_metrics()
        else:
            # 如果数据未加载,显示警告提示
            st.warning("⚠️ 数据加载失败，请检查数据文件")

    # 在Streamlit中,展示豆瓣电影Top250,核心统计指标,以卡片形式呈现8个关键数据维度

    """显示概览-数据概览"""
    def show_summary_metrics(self):
        """显示摘要指标"""
        st.markdown('<h2 class="section-header">📈 数据概览</h2>', unsafe_allow_html=True)
        if self.stats:  # 检查统计数据是否存在
            # st.columns(4)创建4列布局
            col1, col2, col3, col4 = st.columns(4)  # 第一行指标(4列)
            # 在第一列中创建电影总数统计指标
            with col1:
                # 显示榜单中电影总数量（自动格式化为美观的指标卡片）
                st.metric("电影总数", f"{self.stats['total_movies']} 部")
            with col2:
                # 用.get()方法安全访问字典,避免键不存在时报错
                if self.stats.get('rating_stats'):
                    # 所有电影平均分
                    st.metric("平均评分", f"{self.stats['rating_stats']['mean_rating']} 分")
            with col3:
                if self.stats.get('vote_stats'):
                    # 累计的评价人次
                    # self.stats: 统计数据字典
                    # ['vote_stats']: 访问投票统计子字典
                    # ['total_votes']: 获取总评价人数字段
                    total_votes = self.stats['vote_stats']['total_votes']
                    # 对总评价人数，进行数字格式化
                    # 用f-string千位分隔符格式,将数字如1234567转换为1,234,567
                    formatted_votes = f"{total_votes:,}".replace(",", ",")
                    st.metric("总评价人数", f"{formatted_votes} 人")
            with col4:
                if self.stats.get('time_range'):
                    # 榜单电影跨越的年份范围
                    # ['time_range']: 访问时间范围子字典
                    # ['year_span']: 获取年份跨度的数值
                    year_span = self.stats['time_range']['year_span']
                    st.metric("时间跨度", f"{year_span} 年")
                # 更多指标
            col5, col6, col7, col8 = st.columns(4)
            with col5:
                if self.stats.get('country_distribution'):
                    # 电影来源的国家/地区总数
                    countries = self.stats['country_distribution']['total_countries']
                    st.metric("涉及国家/地区", f"{countries} 个")
            with col6:
                if self.stats.get('genre_distribution'):
                    # 涵盖的电影类型种类数
                    genres = self.stats['genre_distribution']['total_genres']
                    st.metric("电影类型", f"{genres} 种")
            with col7:
                if self.stats.get('director_stats'):
                    # 参与创作的导演总数
                    directors = self.stats['director_stats']['total_directors']
                    st.metric("导演数量", f"{directors} 位")
            with col8:
                if self.stats.get('actor_stats'):
                    # 参演演员的总数
                    actors = self.stats['actor_stats']['total_actors']
                    st.metric("演员数量", f"{actors} 位")

    def show_data_explorer(self):
        """显示数据探索器"""
        st.markdown('<h2 class="section-header">🔍 数据探索器</h2>', unsafe_allow_html=True)
        # 检查数据框是否为空
        if self.df is None:
            # 显示警告提示用户
            st.warning("请先加载数据")
            return  # 提前退出方法,不执行后续代码

        # 创建一个可折叠的数据预览区域
        st.subheader("📋 数据预览")  # 显示这个二级标题
        # 创建默认收起的折叠面板,点击展开
        with st.expander("查看完整数据", expanded=False):
            # 面板内，展示完整数据表格，宽度自适应容器
            st.dataframe(self.df, use_container_width=True)

        # 数据统计
        st.subheader("📊 数据统计")  # 显示这个二级标题
        # 创建数据统计区域的双列布局
        col1, col2 = st.columns(2)

        with col1:
            # 显示这个标题
            st.write("**数值列统计:**")
            # select_dtypes(include=[np.number]): 筛选出所有数值型列
            numeric_cols = self.df.select_dtypes(include=[np.number]).columns
            if len(numeric_cols) > 0:
                # st.dataframe():以表格形式展示统计结果
                # self.df[numeric_cols]从数据框中，筛选出所有数值型列的子集
                # describe():生成统计摘要(均值、标准差、最大最小值等)
                st.dataframe(self.df[numeric_cols].describe(), use_container_width=True)
        with col2:
            # 显示标题
            st.write("**缺失值统计:**")
            # 统计并展示，数据集中各列的缺失值
            missing_df = pd.DataFrame({
                '列名': self.df.columns,  # 原始数据字段名
                '缺失数量': self.df.isnull().sum(),  # 是否有缺失，以及缺失数量
                # 缺失比例
                # len(self.df)总行数   round(2)保留两位小数
                '缺失比例': (self.df.isnull().sum() / len(self.df) * 100).round(2)
            })
            # 以表格形式展示缺失值结果
            st.dataframe(missing_df, use_container_width=True)

        # 创建一个电影筛选器的年份选择组件,用户按上映年份筛选电影
        st.subheader("🎯 电影筛选器")  # 标题
        # 创建三列布局
        col1, col2, col3 = st.columns(3)
        # 在第一列中创建电影筛选器
        with col1:
            # 检查列存在
            if '上映年份' in self.df.columns:
                # 从数据框中，提取"上映年份"列，并创建副本
                # copy()创建深拷贝，避免后续操作修改原数据
                years_series = self.df['上映年份'].copy()
                # 将年份列转换为数值类型,无效值转为NaN
                years_numeric = pd.to_numeric(years_series, errors='coerce')
                # 获取有效的数值年份
                valid_years = years_numeric.dropna().unique()
                # 排除异常的负值年份
                valid_years = valid_years[valid_years > 0]
                # 创建多选组件
                if len(valid_years) > 0:
                    # 将有效年份，转换为整数并升序排序
                    # astype(int)将浮点型年份数组转换为整型
                    years = sorted(valid_years.astype(int))
                    # 生成年份多选下拉框
                    selected_years = st.multiselect(
                        "选择上映年份",
                        years,
                        # 默认选中前3个年份(如果年份超过3个)
                        default=years[:3] if len(years) > 3 else years
                    )
                else:
                    # 无有效年份时返回空列表并显示警告
                    selected_years = []
                    st.warning("没有有效的年份数据")
            else:
                # 列不存在时，也返回空列表
                selected_years = []

        # 创建评分范围的滑动条筛选器
        # （用户拖动滑块，选择电影的评分区间）
        with col2:  # 在第二列中创建评分筛选器
            # 检查列存在 -- 确认数据中包含"评分"列
            if '评分' in self.df.columns:
                # 深拷贝
                rating_series = self.df['评分'].copy()
                # 将评分列，转换为数值类型,无效值转为NaN
                rating_numeric = pd.to_numeric(rating_series, errors='coerce')
                # 检查是否存在有效的评分数据
                if rating_numeric.notna().any():
                    # 评分最小值
                    min_val = float(rating_numeric.min())
                    # 评分最大值
                    max_val = float(rating_numeric.max())
                    # 创建滑动条
                    # st.slider():生成可拖动的范围选择器
                    min_rating, max_rating = st.slider(
                        "评分范围",
                        min_value=min_val,  # 滑动条最小值
                        max_value=max_val,  # 滑动条最大值
                        # 默认选中8.0-9.5分范围
                        # max(min_val,8.0)确保默认最小值不低于8.0
                        value=(max(min_val, 8.0), min(max_val, 9.5))
                    )
                else:
                    # 评分数据无效时，设置默认范围0-10，并显示警告
                    min_rating, max_rating = 0, 10
                    st.warning("评分数据无效")
            else:
                # 列不存在时，使用默认范围0-10
                min_rating, max_rating = 0, 10

        # 在第三列中，创建国家筛选器
        # （一部电影涉及多个国家(用"/"分隔),需先解析并提取所有唯一国家,
        # 然后用户选择感兴趣的国家/地区）
        with col3:
            # 检查列存在
            if '国家地区' in self.df.columns:
                all_countries = []
                # 获取所有国家
                # 遍历"国家地区"列的非空值
                for countries in self.df['国家地区'].dropna():
                    # 判断countries是否为str类型
                    if isinstance(countries, str):
                        # countries.split('/'):按斜杠分割(因为一部电影可能有多个国家)
                        # c.strip():去除每个国家名称的前后空格
                        # c（第一个）：每次迭代取出一个国家名称
                        country_list = [c.strip() for c in countries.split('/')]
                        # 将所有国家添加到列表
                        all_countries.extend(country_list)
                # 去重并排序  set()去除重复的国家名  sorted()按字母顺序排序
                unique_countries = sorted(set(all_countries))
                # 创建多选组件
                # st.multiselect():生成国家/地区多选下拉框
                selected_countries = st.multiselect("选择国家/地区", unique_countries)
            else:
                # 列不存在时，返回空列表
                selected_countries = []

        # 创建原始数据框的副本，用于筛选操作
        filtered_df = self.df.copy()

        # 用年份筛选条件，过滤用户选择的年份对应的电影
        if selected_years and '上映年份' in filtered_df.columns:
            # 创建年份的数值版本用于比较
            # 将年份列转换为数值类型,无效值转为NaN
            # 存储为临时列：上映年份_数值
            filtered_df['上映年份_数值'] = pd.to_numeric(filtered_df['上映年份'], errors='coerce')
            # 应用筛选
            # isin(): 检查每部电影的年份，是否在用户选择的年份列表中
            # 保留匹配的电影
            filtered_df = filtered_df[filtered_df['上映年份_数值'].isin(selected_years)]

        # 应用评分范围筛选条件，过滤指定评分区间内的电影
        if '评分' in filtered_df.columns:  # 检查评分列是否存在
            # 将评分列，转换为数值类型，无效值转为NaN
            # 存储为临时列：评分_数值
            filtered_df['评分_数值'] = pd.to_numeric(filtered_df['评分'], errors='coerce')
            # 应用范围筛选
            # >= 评分大于等于最小值
            # <= 评分小于等于最大值
            # 两个条件都满足，保留评分在指定范围内的电影
            filtered_df = filtered_df[
                (filtered_df['评分_数值'] >= min_rating) &
                (filtered_df['评分_数值'] <= max_rating)
                ]

        # 应用国家/地区筛选条件,并显示筛选结果数量
        if selected_countries:  # 检查用户是否选择了国家/地区
            # 创建筛选掩码
            # filtered_df['国家地区'].apply():对每一行的国家地区列使用函数
            mask = filtered_df['国家地区'].apply(
                # 检查该电影，是否包含，任一选中的国家
                # 一部电影可能有多个国家,用模糊匹配(in)而非精确匹配
                lambda x: any(country in str(x) for country in selected_countries)
                # 如果值为空(NaN),返回False
                if pd.notna(x) else False
            )
            # 保留掩码为True的行(匹配的电影)
            filtered_df = filtered_df[mask]
        # 显示蓝色提示框,告知用户筛选出的电影数量
        st.info(f"筛选结果: {len(filtered_df)} 部电影")

        # 展示筛选后电影数据列表
        if len(filtered_df) > 0:  # 检查是否有筛选的结果
            # 指定6个关键信息字段
            display_cols = ['电影名', '评分', '评价人数', '上映年份', '国家地区', '电影类型']
            # 过滤实际存在的列,避免列名不存在报错
            # filtered_df.columns 获取数据框的所有列名
            # if...in...：判断列名是否存在于数据框中
            # col（第一个）: 每次迭代取出一个列名
            display_cols = [col for col in display_cols if col in filtered_df.columns]
            # 展示数据表格
            st.dataframe(  # 以表格形式展示
                # 只选取指定的列
                filtered_df[display_cols],
                # 表格宽度自适应容器
                use_container_width=True
            )

        # 创建Matplotlib图表的基础画布
        # 默认画布大小10x6英寸

    def create_matplotlib_chart(self, figsize=(10, 6)):
        # 创建图形对象和坐标轴
        # fig：Figure对象，代表整个图形窗口
        # ax：Axes对象，代表绘图区域，用于调用绘图方法
        fig, ax = plt.subplots(figsize=figsize)
        # 返回两个对象供后续绘图使用
        return fig, ax

    def show_charts_dashboard(self):
        """显示图表仪表板"""
        st.markdown('<h2 class="section-header">📊 可视化图表</h2>', unsafe_allow_html=True)
        # 判断数据框是否为空
        if self.df is None:
            # 显示黄色警告提示"请先加载数据"
            st.warning("请先加载数据")
            # 提前退出方法,阻止后续执行
            return

        # 图表类型映射字典，将中文显示名称，映射到内部分析方法标识
        # 键:用户友好的中文选项
        # 值:对应的分析方法名
        chart_options = {
            "评分分布": "rating",
            "年份趋势": "year_trend",
            "国家分布": "country",
            "类型分布": "genre",
            "导演分析": "director",
            "演员分析": "actor",
            "Top电影": "top_movies",
            "相关性分析": "correlation"
        }

        # 创建一个多选下拉框,用户选择要显示的可视化图表类型
        selected_charts = st.multiselect(
            "选择要显示的图表",  # 文本标签
            # 从chart_options字典提取所有键
            # list():将迭代对象转换为列表
            list(chart_options.keys()),  # 所有选项:8个中文图表名称
            default=list(chart_options.keys())[:4]  # 默认选中前4个图表
        )

        # 遍历用户选择的图表,逐个生成并显示可视化图表
        # 遍历用户选中的中文图表名称
        for chart_name in selected_charts:
            # 从chart_options字典，查找对应的分析类型
            chart_type = chart_options[chart_name]
            # 调用方法生成并显示图表
            self.display_chart(chart_type, chart_name)

    def display_chart(self, chart_type, chart_name):
        """显示单个图表"""
        st.subheader(f"📈 {chart_name}")

        if chart_type == "rating":  # 评分分布
            self.show_rating_charts()
        elif chart_type == "year_trend":  # 年份趋势
            self.show_year_trend_charts()
        elif chart_type == "country":  # 国家分布
            self.show_country_charts()
        elif chart_type == "genre":  # 类型分布
            self.show_genre_charts()
        elif chart_type == "director":  # 导演分析
            self.show_director_charts()
        elif chart_type == "actor":  # 演员分析
            self.show_actor_charts()
        elif chart_type == "top_movies":  # top电影
            self.show_top_movies_charts()
        elif chart_type == "correlation":  # 相关性分析
            self.show_correlation_charts()

    def show_rating_charts(self):
        # 判断数据框中，是否缺少"评分"列
        if '评分' not in self.df.columns:
            # 显示黄色警告，提示"评分数据不可用"
            st.warning("评分数据不可用")
            # 提前退出方法，阻止后续绘图操作
            return

        # 创建双列布局
        col1, col2 = st.columns(2)
        # 在第一列中渲染
        with col1:
            # 创建评分分布直方图
            fig, ax = self.create_matplotlib_chart()
            # 绘制直方图,20个分组,半透明蓝色柱体
            # dropna():排除空值
            # edgecolor='white'图形边框颜色为白色
            ax.hist(self.df['评分'].dropna(), bins=20, alpha=0.7, color='#2E86AB', edgecolor='white')
            # 设置坐标轴标签
            ax.set_xlabel('评分')
            ax.set_ylabel('电影数量')
            # 设置标题
            ax.set_title('评分分布直方图')
            ax.grid(True, alpha=0.3)
            # 渲染图表
            st.pyplot(fig)

        with col2:
            # 创建评分箱线图,展示评分的分布统计特征
            # 设置画布大小8x6英寸
            fig, ax = self.create_matplotlib_chart(figsize=(8, 6))
            # vert=False:绘制水平箱线图
            # patch_artist=True:启用箱体填充色
            # facecolor='#F18F01':橙色箱体,半透明
            ax.boxplot(self.df['评分'].dropna(), vert=False, patch_artist=True,
                       boxprops=dict(facecolor='#F18F01', alpha=0.7))
            ax.set_xlabel('评分')
            ax.set_title('评分箱线图')
            ax.grid(True, alpha=0.3)
            st.pyplot(fig)

    def show_year_trend_charts(self):
        # 判断数据框中，是否缺少"上映年份"列
        if '上映年份' not in self.df.columns:
            # 显示黄色警告提示"上映年份数据不可用"
            st.warning("上映年份数据不可用")
            return
        # 创建数据副本，避免修改原数据
        df_year = self.df.copy()
        # 转换年份为数值,无效值变NaN
        df_year['上映年份'] = pd.to_numeric(df_year['上映年份'], errors='coerce')
        # 删除年份为空的行
        df_year = df_year.dropna(subset=['上映年份'])
        # 检查是否有有效数据
        if len(df_year) == 0:
            # 没有就警告并退出
            st.warning("有效的年份数据不足")
            return

        # 按年份统计数据
        # 按年份分组；agg():对每组计算多个统计指标；
        year_stats = df_year.groupby('上映年份').agg({
            '电影名': 'count',  # 每年电影数量
            '评分': 'mean',  # 每年平均评分
            '评价人数': 'mean'  # 每年平均评价人数
        }).reset_index()  # 重置索引使年份变为普通列
        # 将英文列名改为中文描述性名称
        year_stats.columns = ['上映年份', '电影数量', '平均评分', '平均评价人数']

        col1, col2 = st.columns(2)
        with col1:
            # 电影数量年份分布
            fig, ax = self.create_matplotlib_chart()
            # 绘制彩色柱状图展示每年电影数量分布
            # ax.bar(): 绘制柱状图,X轴为年份,Y轴为电影数量
            # color为用Seaborn的viridis渐变色系,为每个年份柱子分配不同颜色
            ax.bar(year_stats['上映年份'], year_stats['电影数量'],
                   color=sns.color_palette("viridis", len(year_stats)))
            ax.set_xlabel('上映年份')
            ax.set_ylabel('电影数量')
            ax.set_title('各年份电影数量分布')
            ax.grid(True, alpha=0.3)
            #  设置X轴刻度样式
            # rotation=45:将年份标签逆时针旋转45度
            plt.xticks(rotation=45)
            st.pyplot(fig)

        with col2:
            # 评分趋势
            fig, ax = self.create_matplotlib_chart()
            # 绘制年份与平均评分的折线图
            # ax.plot():绘制折线图，X轴为年份，Y轴为平均评分
            # marker='o':每个数据点添加圆形标记
            # color='#A23B72':紫红色线条
            # linewidth=2:线宽为2，加粗显示
            ax.plot(year_stats['上映年份'], year_stats['平均评分'],
                    marker='o', color='#A23B72', linewidth=2)
            ax.set_xlabel('上映年份')
            ax.set_ylabel('平均评分')
            ax.set_title('平均评分年份趋势')
            ax.grid(True, alpha=0.3)
            plt.xticks(rotation=45)
            st.pyplot(fig)

    def show_country_charts(self):
        if '国家地区' not in self.df.columns:
            st.warning("国家地区数据不可用")
            return
        # 提取国家数据
        country_data = []
        # 遍历"国家地区"列的每个值
        for countries in self.df['国家地区']:
            # pd.notna(countries):排除空值
            # str(countries) != '未知':排除"未知"值
            if pd.notna(countries) and str(countries) != '未知':
                # split('/'):按斜杠分割
                # strip():去除每个国家名的前后空格
                country_list = [c.strip() for c in str(countries).split('/')]
                # 将所有国家添加到列表
                country_data.extend(country_list)
        # 不存在国家数据
        if not country_data:
            st.warning("没有有效的国家地区数据")
            return
        # 统计出现频次，最高的前10个国家/地区
        # pd.Series(country_data):将国家列表转换为Series对象
        # value_counts():统计每个国家出现次数(电影数量),自动降序排列
        # head(10):取前10个最高频的国家
        country_counts = pd.Series(country_data).value_counts().head(10)

        col1, col2 = st.columns(2)
        with col1:
            # 国家分布条形图
            fig, ax = self.create_matplotlib_chart(figsize=(10, 6))
            # 生成Y轴位置的数字序列
            # len(country_counts):获取国家数量
            # range():创建从0开始，连续整数序列
            y_pos = range(len(country_counts))
            # 绘制水平条形图展示国家分布
            # ax.barh():绘制水平条形图
            # y_pos:Y轴位置序列(0-9)
            # country_counts.values:每个国家电影数量
            # color 用蓝色渐变色系，为每个条形，分配不同深浅的蓝色
            ax.barh(y_pos, country_counts.values, color=sns.color_palette("Blues", len(country_counts)))
            ax.set_yticks(y_pos)
            # 设置Y轴刻度标签为国家名称
            # ax.set_yticklabels():自定义Y轴的刻度标签文本
            # index 使用国家名称列表作为标签
            ax.set_yticklabels(country_counts.index)
            ax.set_xlabel('电影数量')
            ax.set_title('Top10 国家/地区分布')
            # alpha=0.3:设置透明度为30%，使网格线半透明不突兀
            # 添加X轴方向的网格线
            ax.grid(True, alpha=0.3, axis='x')
            st.pyplot(fig)

        with col2:
            # 国家分布饼图
            fig, ax = self.create_matplotlib_chart(figsize=(8, 8))
            # 绘制饼图展示国家分布占比
            # ax.pie():绘制饼图
            # labels=country_counts.index:国家名称标签
            # autopct='%1.1f%%':显示百分比，保留1位小数
            # color 用Set3颜色系，为每个饼块分配不同颜色
            ax.pie(country_counts.values, labels=country_counts.index, autopct='%1.1f%%',
                   colors=sns.color_palette("Set3", len(country_counts)))
            ax.set_title('Top10 国家/地区占比')
            st.pyplot(fig)

    def show_genre_charts(self):
        # 判断数据框中，是否缺少"电影类型"列
        if '电影类型' not in self.df.columns:
            st.warning("电影类型数据不可用")
            return
        # 提取类型数据
        genre_data = []
        # 遍历"电影类型"列的每个值
        # pd.notna(genres):排除空值
        # str(genres)!='未知':排除"未知"值
        for genres in self.df['电影类型']:
            if pd.notna(genres) and str(genres) != '未知':
                genre_list = [g.strip() for g in str(genres).split('/')]
                genre_data.extend(genre_list)
        if not genre_data:
            st.warning("没有有效的电影类型数据")
            return
        # pd.Series(genre_data):将类型列表转换为Series对象
        # value_counts():统计每个类型的出现次数，自动降序排列
        # head(10):取前10个最高频的类型
        genre_counts = pd.Series(genre_data).value_counts().head(10)

        col1, col2 = st.columns(2)
        with col1:
            # 类型分布条形图
            fig, ax = self.create_matplotlib_chart(figsize=(10, 6))
            y_pos = range(len(genre_counts))
            # 绘制水平条形图，展示电影类型分布
            # ax.barh():绘制水平条形图
            # y_pos:Y轴位置坐标
            # genre_counts.values:各类型的电影数量
            # sns.color_palette("Greens",...):用绿色渐变色系，每种类型分配不同深浅的绿色
            ax.barh(y_pos, genre_counts.values, color=sns.color_palette("Greens", len(genre_counts)))
            ax.set_yticks(y_pos)
            # 将Y轴的数字索引，替换为具体的电影类型
            ax.set_yticklabels(genre_counts.index)
            # 设置X轴的标签文本
            ax.set_xlabel('出现次数')
            ax.set_title('Top10 电影类型分布')
            # true表示启用网格线
            # 显示x轴透明度为30%的网格线
            ax.grid(True, alpha=0.3, axis='x')
            st.pyplot(fig)

    def show_director_charts(self):
        """显示导演分析图表"""
        # 判断数据框中，是否缺少"导演"列
        if '导演' not in self.df.columns:
            st.warning("导演数据不可用")
            return

        # 提取导演数据
        director_data = []
        for directors in self.df['导演']:
            if pd.notna(directors) and str(directors) != '未知':
                # if d.strip():保留非空字符串
                # d（第一个）遍历导演列表时，单个导演名称变量
                director_list = [d.strip() for d in str(directors).split(',') if d.strip()]
                director_data.extend(director_list)

        if not director_data:
            st.warning("没有有效的导演数据")
            return
        director_counts = pd.Series(director_data).value_counts().head(10)

        # 高产导演条形图
        fig, ax = self.create_matplotlib_chart(figsize=(10, 6))
        y_pos = range(len(director_counts))
        ax.barh(y_pos, director_counts.values, color=sns.color_palette("Reds", len(director_counts)))
        ax.set_yticks(y_pos)
        ax.set_yticklabels(director_counts.index)
        ax.set_xlabel('电影数量')
        ax.set_title('Top10 高产导演')
        ax.grid(True, alpha=0.3, axis='x')
        st.pyplot(fig)

    def show_actor_charts(self):
        """显示演员分析图表"""
        if '演员' not in self.df.columns:
            st.warning("演员数据不可用")
            return

        # 提取演员数据
        actor_data = []
        for actors in self.df['演员']:
            if pd.notna(actors) and str(actors) != '未知':
                actor_list = [a.strip() for a in str(actors).split('/') if a.strip()]
                actor_data.extend(actor_list)

        if not actor_data:
            st.warning("没有有效的演员数据")
            return
        actor_counts = pd.Series(actor_data).value_counts().head(10)

        # 频繁出演演员条形图
        fig, ax = self.create_matplotlib_chart(figsize=(12, 6))
        x_pos = range(len(actor_counts))
        bars = ax.bar(x_pos, actor_counts.values, color=sns.color_palette("Purples", len(actor_counts)))
        ax.set_xticks(x_pos)
        # set_xticklabels():自定义X轴刻度标签文本
        # actor_counts.index:使用演员名称作为标签
        # rotation=45:标签逆时针旋转45度，避免重叠
        # ha='right':标签文本居右（horizontal alignment）
        # （旋转后的标签，与刻度线正确对齐）
        ax.set_xticklabels(actor_counts.index, rotation=45, ha='right')
        ax.set_ylabel('出演电影数量')
        ax.set_title('Top10 频繁出演演员')
        ax.grid(True, alpha=0.3, axis='y')

        # 添加数值标签
        for bar in bars:
            # bar 一个矩形柱子对象
            # get_height():返回该柱子数值高度(Y轴对应的值)
            height = bar.get_height()
            # 在每个柱子顶部，添加具体数量值，让用户能精确读取，
            # 每个演员的电影数量，而不需要估算Y轴高度
            # annotate 是Matplotlib的注释标注函数
            ax.annotate(f'{int(height)}',
                        # xy - 定位柱子顶部中心位置
                        xy=(bar.get_x() + bar.get_width() / 2, height),
                        # 向上偏移3个点，避免遮挡
                        xytext=(0, 3),
                        # 使用相对偏移坐标
                        textcoords="offset points",
                        # 水平居中，垂直底部对齐
                        ha='center', va='bottom')

        st.pyplot(fig)

    def show_top_movies_charts(self):
        """显示Top电影图表"""
        # 判断数据是否已成功加载
        if self.df is None:
            return

        col1, col2 = st.columns(2)
        with col1:
            # 按"评分"列降序排序，取前10条记录
            # nlargest是Pandas的取最大值方法
            top_rated = self.df.nlargest(10, '评分')
            fig, ax = self.create_matplotlib_chart(figsize=(10, 8))
            y_pos = range(len(top_rated))
            bars = ax.barh(y_pos, top_rated['评分'],
                           color=sns.color_palette("viridis", len(top_rated)))
            ax.set_yticks(y_pos)

            # 处理电影名称长度
            y_labels = []
            for name in top_rated['电影名']:
                # 截断过长的电影名称
                if len(name) > 20:
                    # 截取前18个字符，并添加省略号
                    y_labels.append(name[:18] + '...')
                else:
                    # 否则保留原名
                    y_labels.append(name)

            ax.set_yticklabels(y_labels)
            ax.set_xlabel('评分')
            ax.set_title('Top10 最高评分电影')
            ax.grid(True, alpha=0.3, axis='x')

            # 在每个电影条形右侧，显示具体评分值
            # zip() 同时遍历柱子和对应评分（将两者配对，每次迭代同时获取）
            # bar.get_width()+0.05:X轴位置(柱子宽度右侧偏移0.05)
            # bar.get_y()+bar.get_height()/2:Y轴位置(柱子垂直中心)
            # rating:对应的评分值
            for bar, rating in zip(bars, top_rated['评分']):
                ax.text(bar.get_width() + 0.05, bar.get_y() + bar.get_height() / 2,
                        f'{rating}', ha='left', va='center')
            st.pyplot(fig)

        with col2:
            # 获取评价人数最多的前10部电影
            most_popular = self.df.nlargest(10, '评价人数')
            fig, ax = self.create_matplotlib_chart(figsize=(10, 8))
            y_pos = range(len(most_popular))
            bars = ax.barh(y_pos, most_popular['评价人数'],
                           color=sns.color_palette("plasma", len(most_popular)))
            ax.set_yticks(y_pos)

            # 处理电影名称长度
            y_labels = []
            for name in most_popular['电影名']:
                if len(name) > 20:
                    y_labels.append(name[:18] + '...')
                else:
                    y_labels.append(name)

            ax.set_yticklabels(y_labels)
            ax.set_xlabel('评价人数')
            ax.set_title('Top10 最受欢迎电影')
            ax.grid(True, alpha=0.3, axis='x')
            # 将X轴，从线性刻度，改为对数刻度(以10为底)
            # 用于处理，评价人数，数据跨度极大的情况(如几万到几百万)
            ax.set_xscale('log')
            st.pyplot(fig)

    def show_correlation_charts(self):
        """显示相关性分析图表"""
        if self.df is None:
            return
        # 选择数值列
        numeric_columns = []
        # 循环迭代三个关键指标字段，依次处理
        for col in ['评分', '评价人数', '上映年份']:
            if col in self.df.columns:
                df_temp = self.df.copy()
                # 特别处理"上映年份"等可能含非数值数据的列
                if col == '上映年份':
                    # 强制转换列为数值型，无效值转为NaN
                    # 确保后续分析，使用纯数值数据
                    df_temp[col] = pd.to_numeric(df_temp[col], errors='coerce')
                numeric_columns.append(col)
        # 判断数值列是否少于2列
        if len(numeric_columns) < 2:
            st.warning("数值列不足，无法进行相关性分析")
            return
        # 生成纯净的数值型DataFrame，确保分析无缺失值干扰
        # self.df[numeric_columns]:选取所有数值列
        # apply() 批量转换为数值型，无效值变NaN
        # dropna():删除含空值的行
        df_numeric = self.df[numeric_columns].apply(pd.to_numeric, errors='coerce').dropna()
        # 判断清洗后的数据是否少于2行
        if len(df_numeric) < 2:
            st.warning("有效数据不足，无法进行相关性分析")
            return
        # 计算数值列之间的相关系数矩阵
        # （使用皮尔逊相关系数，计算每对变量间的线性相关性）
        corr_matrix = df_numeric.corr()
        # 相关性热力图
        st.subheader("相关性热力图")
        fig, ax = self.create_matplotlib_chart(figsize=(8, 6))
        # 绘制热力图
        # sns.heatmap():Seaborn热力图函数
        # annot=True:在格子中显示相关系数数值
        # cmap='coolwarm':使用蓝-红渐变色系(负相关蓝色，正相关红色)
        # center=0:将颜色中心为0，正相关变红，负相关变蓝
        # ax=ax:指定绘图的坐标轴
        sns.heatmap(corr_matrix, annot=True, cmap='coolwarm', center=0, ax=ax)
        ax.set_title('变量相关性热力图')
        st.pyplot(fig)

        # 散点图
        if len(numeric_columns) >= 2:
            st.subheader("变量关系散点图")
            # 评分 vs 评价人数
            if '评分' in df_numeric.columns and '评价人数' in df_numeric.columns:
                fig, ax = self.create_matplotlib_chart(figsize=(10, 6))
                # 绘制散点图，展示两个变量的关系
                # scatter():创建散点图
                # X轴:评价人数；Y轴:评分
                # color 蓝色数据点
                # s=50:每个点大小为50像素
                ax.scatter(df_numeric['评价人数'], df_numeric['评分'],
                           alpha=0.6, color='#2E86AB', s=50)
                ax.set_xlabel('评价人数')
                ax.set_ylabel('评分')
                ax.set_title('评分 vs 评价人数')
                # 将X轴，从线性刻度，改为对数刻度(以10为底)
                ax.set_xscale('log')
                ax.grid(True, alpha=0.3)
                st.pyplot(fig)

    def show_insights(self):
        """显示数据洞察"""
        st.markdown('<h2 class="section-header">💡 数据洞察</h2>', unsafe_allow_html=True)
        # 判断统计字典，是否已初始化且非空
        # 若存在，后续会生成数据洞察信息
        if self.stats:
            insights = []
            # 评分洞察
            # 检查评分统计是否存在
            if self.stats.get('rating_stats'):
                # 提取平均分
                mean_rating = self.stats['rating_stats']['mean_rating']
                # 提取最高分
                max_rating = self.stats['rating_stats']['max_rating']
                insights.append(f"📊 **评分分析**: Top250电影平均分为{mean_rating}分，最高分{max_rating}分")
            # 时间洞察
            # 检查时间范围统计是否存在
            if self.stats.get('time_range'):
                # 获取年份跨度数值
                year_span = self.stats['time_range']['year_span']
                # 展示榜单电影，涵盖的时间范围宽度
                insights.append(f"⏳ **时间跨度**: 电影涵盖{year_span}年的时间范围")
            # 国家洞察
            # 检查国家分布统计是否存在
            if self.stats.get('country_distribution'):
                # items()[0]:获取字典第一个键值对(最高频国家)
                # top_country:元组格式(国家名，数量)
                top_country = list(self.stats['country_distribution']['top_countries'].items())[0]
                # 展示哪个国家的电影，在Top250中占比最大
                insights.append(f"🌍 **地域分布**: {top_country[0]}的电影最多，共{top_country[1]}部")
            # 类型洞察
            # 检查类型分布统计是否存在
            if self.stats.get('genre_distribution'):
                # 最高频类型
                # top_genre:元组格式(类型名, 数量)
                top_genre = list(self.stats['genre_distribution']['top_genres'].items())[0]
                # 展示哪种电影类型，在Top250中最受欢迎
                insights.append(f"🎭 **类型偏好**: {top_genre[0]}类型最受欢迎，出现{top_genre[1]}次")
            # 导演洞察
            # 检查导演统计是否存在
            if self.stats.get('director_stats'):
                # 最高产导演
                # top_director:元组格式(导演名，作品数)
                top_director = list(self.stats['director_stats']['top_directors'].items())[0]
                # 展示哪位导演，在Top250中上榜作品最多
                insights.append(f"🎥 **导演贡献**: {top_director[0]}导演作品最多，有{top_director[1]}部")
            # 遍历洞察列表
            for insight in insights:
                # 用蓝色提示框，展示每条洞察
                st.info(insight)

def main():
    """主函数"""
    # 初始化应用
    dashboard = DouBanDashBoard()
    # 侧边栏
    with st.sidebar:
        st.title("🎬 豆瓣电影Top250")
        # 渲染水平分隔线
        st.divider()
        # 页面选择
        page_options = {
            "🏠 概览": "overview",
            "🔍 数据探索": "explorer",
            "📊 可视化图表": "charts",
            "💡 数据洞察": "insights"
        }
        # 生成单选组件
        selected_page = st.radio(
            "导航菜单",  # 标签文本
            list(page_options.keys()),  # 选项列表(概览、数据探索、可视化图表、数据洞察)
            index=0  # 默认选中第一个选项
        )
        # 渲染水平分隔线
        st.divider()
    # 用Streamlit会话状态机制，在应用刷新时，保持用户选择的页面，避免重复初始化
    # 检查会话中是否已有page变量
    if 'page' not in st.session_state:
        # 首次运行时设置默认页面
        st.session_state.page = page_options[selected_page]
    # 自动加载数据
    if dashboard.df is None:
        dashboard.load_data()
    # 将中文选项，映射为内部页面标识
    page_key = page_options[selected_page]
    # 判断页面类型，并调用对应的显示方法
    if page_key == "overview":
        dashboard.show_overview()
    elif page_key == "explorer":
        dashboard.show_data_explorer()
    elif page_key == "charts":
        dashboard.show_charts_dashboard()
    elif page_key == "insights":
        dashboard.show_insights()

if __name__ == "__main__":
    main()

# 当前这个py文件如何启动？   streamlit run app.py  （如果用这个命令来启动，需要输入邮箱）
#                                    指定端口号            无头模式，跳过邮箱输入提示
#   python -m streamlit run app.py --server.port 8501 --server.headless true

