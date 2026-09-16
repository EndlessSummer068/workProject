import streamlit as st
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')
from pathlib import Path
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 导入自定义模块
try:
    from data_processing.cleaner import PoetryCleaner
    from data_processing.analyzer import PoetryAnalyzer, setup_chinese_font
    from spiders.spider import PoetrySpider, Config
except ImportError as e:
    st.error(f"导入模块失败: {e}")
    st.info("请确保项目结构正确，且已安装所有依赖")


# ==================== 全局样式 ====================
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
    .poem-card {
        background-color: #fff;
        border-radius: 10px;
        padding: 1.2rem;
        margin-bottom: 1rem;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        border-left: 4px solid #F18F01;
    }
    .poem-title {
        font-size: 1.3rem;
        font-weight: bold;
        color: #2E86AB;
        margin-bottom: 0.3rem;
    }
    .poem-author {
        font-size: 0.95rem;
        color: #A23B72;
        margin-bottom: 0.6rem;
    }
    .poem-content {
        font-size: 1.05rem;
        line-height: 1.8;
        color: #333;
    }
    .poem-tags {
        margin-top: 0.6rem;
        font-size: 0.85rem;
        color: #6c757d;
    }
</style>
""", unsafe_allow_html=True)


class PoetryDashboard:
    def __init__(self):
        self.analyzer = PoetryAnalyzer()
        self.df = None
        self.stats = None

    def load_data(self):
        """加载数据"""
        if self.analyzer.load_data():
            self.df = self.analyzer.df
            self.stats = self.analyzer.basic_statistics()
            return True
        return False

    # ==================== 概览页 ====================
    def show_overview(self):
        st.markdown(
            '<h1 class="main-header">📜 古诗词数据分析</h1>', unsafe_allow_html=True
        )
        st.markdown("""
                ### 项目简介
                本项目对古诗词网收录的诗词进行全面的数据分析，包括：
                - 📚 **诗词信息统计**：朝代、作者、标签分布
                - 📝 **正文分析**：字数分布、长度趋势
                - 📊 **可视化图表**：多种图表展示数据洞察
                - 🔍 **深度挖掘**：朝代演变、热门主题、高产诗人

                使用左侧导航菜单切换不同功能模块。
            """)
        st.divider()

        if self.df is not None:
            self.show_summary_metrics()
        else:
            st.warning("⚠️ 数据加载失败，请检查数据文件")

    def show_summary_metrics(self):
        """显示摘要指标（两行 × 4 列）"""
        st.markdown('<h2 class="section-header">📈 数据概览</h2>', unsafe_allow_html=True)
        if not self.stats:
            return

        col1, col2, col3, col4 = st.columns(4)
        with col1:
            st.metric("诗词总数", f"{self.stats['total_poems']} 首")
        with col2:
            if self.stats.get('dynasty_stats'):
                st.metric("涉及朝代", f"{self.stats['dynasty_stats']['total_dynasties']} 个")
        with col3:
            if self.stats.get('author_stats'):
                # 排除佚名后的作者数
                real_authors = self.stats['author_stats']['total_authors'] - 1 \
                    if self.stats['author_stats']['anonymous_count'] > 0 \
                    else self.stats['author_stats']['total_authors']
                st.metric("涉及作者", f"{real_authors} 位")
        with col4:
            if self.stats.get('tag_stats'):
                st.metric("标签种类", f"{self.stats['tag_stats']['total_tags']} 种")

        col5, col6, col7, col8 = st.columns(4)
        with col5:
            if self.stats.get('content_stats'):
                st.metric("平均字数", f"{self.stats['content_stats']['avg_length']} 字")
        with col6:
            if self.stats.get('content_stats'):
                st.metric("中位字数", f"{self.stats['content_stats']['median_length']} 字")
        with col7:
            if self.stats.get('author_stats'):
                st.metric("佚名作品", f"{self.stats['author_stats']['anonymous_count']} 首")
        with col8:
            if self.stats.get('dynasty_stats') and self.stats['dynasty_stats']['top_dynasty']:
                st.metric("最多朝代", f"{self.stats['dynasty_stats']['top_dynasty']}")

    # ==================== 数据探索 ====================
    def show_data_explorer(self):
        st.markdown('<h2 class="section-header">🔍 数据探索器</h2>', unsafe_allow_html=True)
        if self.df is None:
            st.warning("请先加载数据")
            return

        # 数据预览
        st.subheader("📋 数据预览")
        with st.expander("查看完整数据", expanded=False):
            st.dataframe(self.df, use_container_width=True)

        # 数据统计
        st.subheader("📊 数据统计")

        # ---------- 数值列统计 ----------
        st.write("**数值列统计:**")
        numeric_cols = self.df.select_dtypes(include=[np.number]).columns
        if len(numeric_cols) > 0:
            desc_df = self.df[numeric_cols].describe().reset_index()
            desc_df = desc_df.rename(columns={'index': '统计量'})

            st.dataframe(
                desc_df,
                use_container_width=True,
                hide_index=True,
                height="auto",  # ★ 关键 1：高度自适应内容
                column_config={
                    "统计量": st.column_config.TextColumn("统计量", width="small"),
                    **{
                        col: st.column_config.NumberColumn(col, width="small", format="%.2f")
                        for col in numeric_cols
                    }
                }
            )
        else:
            st.info("没有数值列")

        st.write("")

        # ---------- 缺失值统计 ----------
        st.write("**缺失值统计:**")
        missing_df = pd.DataFrame({
            '列名': self.df.columns,
            '缺失数量': self.df.isnull().sum().values,
            '缺失比例(%)': (self.df.isnull().sum() / len(self.df) * 100).round(2).values
        })

        st.dataframe(
            missing_df,
            use_container_width=True,
            hide_index=True,
            height="auto",  # ★ 关键 1
            column_config={
                "列名": st.column_config.TextColumn("列名", width="small"),
                "缺失数量": st.column_config.NumberColumn("缺失数量", width="small"),
                "缺失比例(%)": st.column_config.NumberColumn(
                    "缺失比例(%)", width="small", format="%.2f"
                ),
            }
        )

        # ==================== 筛选器 ====================
        st.subheader("🎯 诗词筛选器")
        col1, col2, col3 = st.columns(3)

        # 1. 朝代筛选
        with col1:
            if '朝代' in self.df.columns:
                dynasties = sorted([d for d in self.df['朝代'].dropna().unique() if d != '未知'])
                selected_dynasties = st.multiselect(
                    "选择朝代",
                    dynasties,
                    default=dynasties[:3] if len(dynasties) > 3 else dynasties
                )
            else:
                selected_dynasties = []

        # 2. 作者筛选
        with col2:
            if '作者' in self.df.columns:
                authors = sorted([a for a in self.df['作者'].dropna().unique()
                                  if a not in ['佚名', '未知']])
                # 默认不选，避免选项太多
                selected_authors = st.multiselect("选择作者（可不选）", authors)
            else:
                selected_authors = []

        # 3. 标签筛选
        with col3:
            if '标签' in self.df.columns:
                all_tags = set()
                for tags in self.df['标签'].dropna():
                    if isinstance(tags, str):
                        for t in tags.split(','):
                            t = t.strip()
                            if t:
                                all_tags.add(t)
                unique_tags = sorted(all_tags)
                selected_tags = st.multiselect("选择标签（可不选）", unique_tags)
            else:
                selected_tags = []

        # 正文长度范围
        st.write("**正文字数范围筛选:**")
        if '正文长度' in self.df.columns:
            max_len = int(self.df['正文长度'].max()) if self.df['正文长度'].max() > 0 else 100
            length_range = st.slider(
                "正文字数范围",
                min_value=0,
                max_value=max_len,
                value=(0, max_len)
            )
        else:
            length_range = None

        # ==================== 应用筛选 ====================
        filtered_df = self.df.copy()

        if selected_dynasties and '朝代' in filtered_df.columns:
            filtered_df = filtered_df[filtered_df['朝代'].isin(selected_dynasties)]

        if selected_authors and '作者' in filtered_df.columns:
            filtered_df = filtered_df[filtered_df['作者'].isin(selected_authors)]

        if selected_tags and '标签' in filtered_df.columns:
            mask = filtered_df['标签'].apply(
                lambda x: any(tag in str(x) for tag in selected_tags)
                if pd.notna(x) else False
            )
            filtered_df = filtered_df[mask]

        if length_range and '正文长度' in filtered_df.columns:
            filtered_df = filtered_df[
                (filtered_df['正文长度'] >= length_range[0]) &
                (filtered_df['正文长度'] <= length_range[1])
            ]

        st.info(f"筛选结果: {len(filtered_df)} 首诗词")

        # ==================== 展示结果 ====================
        if len(filtered_df) > 0:
            display_cols = ['标题', '作者', '朝代', '正文', '标签']
            display_cols = [col for col in display_cols if col in filtered_df.columns]
            st.dataframe(
                filtered_df[display_cols],
                use_container_width=True,
                height=500
            )

            # 随机展示一首
            st.subheader("🎴 随机推荐一首")
            sample = filtered_df.sample(1).iloc[0]
            tags_str = str(sample.get('标签', '')).replace(',', ' · ')
            st.markdown(f"""
                <div class="poem-card">
                    <div class="poem-title">{sample.get('标题', '无题')}</div>
                    <div class="poem-author">{sample.get('朝代', '')} · {sample.get('作者', '佚名')}</div>
                    <div class="poem-content">{sample.get('正文', '')}</div>
                    <div class="poem-tags">🏷️ {tags_str}</div>
                </div>
            """, unsafe_allow_html=True)

    # ==================== 图表工具 ====================
    def create_matplotlib_chart(self, figsize=(10, 6)):
        fig, ax = plt.subplots(figsize=figsize)
        return fig, ax

    # ==================== 可视化仪表盘 ====================
    def show_charts_dashboard(self):
        st.markdown('<h2 class="section-header">📊 可视化图表</h2>', unsafe_allow_html=True)
        if self.df is None:
            st.warning("请先加载数据")
            return

        chart_options = {
            "朝代分布": "dynasty",
            "高产诗人": "author",
            "标签分布": "tag",
            "正文字数分析": "content_length",
            "朝代长度趋势": "dynasty_trend",
            "标签×朝代热力图": "heatmap",
            "作者朝代分布": "author_dynasty"
        }

        selected_charts = st.multiselect(
            "选择要显示的图表",
            list(chart_options.keys()),
            default=list(chart_options.keys())[:3]
        )

        for chart_name in selected_charts:
            chart_type = chart_options[chart_name]
            self.display_chart(chart_type, chart_name)

    def display_chart(self, chart_type, chart_name):
        st.subheader(f"📈 {chart_name}")
        if chart_type == "dynasty":
            self.show_dynasty_charts()
        elif chart_type == "author":
            self.show_author_charts()
        elif chart_type == "tag":
            self.show_tag_charts()
        elif chart_type == "content_length":
            self.show_content_length_charts()
        elif chart_type == "dynasty_trend":
            self.show_dynasty_trend_charts()
        elif chart_type == "heatmap":
            self.show_heatmap_charts()
        elif chart_type == "author_dynasty":
            self.show_author_dynasty_charts()

    # ==================== 各图表 ====================
    def show_dynasty_charts(self):
        """朝代分布：柱状图 + 饼图"""
        if '朝代' not in self.df.columns:
            st.warning("朝代数据不可用")
            return

        dynasty_counts = self.df['朝代'].value_counts()
        dynasty_counts = dynasty_counts[dynasty_counts.index != '未知']
        if len(dynasty_counts) == 0:
            st.warning("没有有效的朝代数据")
            return

        # 按时间顺序排序
        order = ['先秦', '两汉', '魏晋', '南北朝', '隋代', '唐代', '五代',
                 '宋代', '金朝', '元代', '明代', '清代', '近代', '现代', '当代']
        ordered = [d for d in order if d in dynasty_counts.index]
        dynasty_counts = dynasty_counts.reindex(ordered)

        col1, col2 = st.columns(2)
        with col1:
            fig, ax = self.create_matplotlib_chart(figsize=(10, 6))
            colors = sns.color_palette("Spectral", len(dynasty_counts))
            bars = ax.bar(dynasty_counts.index, dynasty_counts.values, color=colors)
            ax.set_xlabel('朝代')
            ax.set_ylabel('诗词数量')
            ax.set_title('各朝代诗词数量分布')
            ax.grid(True, alpha=0.3, axis='y')
            plt.xticks(rotation=45, ha='right')
            for bar in bars:
                h = bar.get_height()
                ax.text(bar.get_x() + bar.get_width() / 2, h + 2, f'{int(h)}',
                        ha='center', va='bottom', fontsize=9)
            st.pyplot(fig)

        with col2:
            fig, ax = self.create_matplotlib_chart(figsize=(10, 8))
            ax.pie(dynasty_counts.values, labels=dynasty_counts.index,
                   autopct='%1.1f%%', startangle=90, colors=colors)
            ax.set_title('朝代占比')
            st.pyplot(fig)

    def show_author_charts(self):
        """Top15 高产诗人"""
        if '作者' not in self.df.columns:
            st.warning("作者数据不可用")
            return

        author_counts = self.df['作者'].value_counts()
        author_counts = author_counts[author_counts.index != '佚名'].head(15)
        if len(author_counts) == 0:
            st.warning("没有有效的作者数据")
            return

        fig, ax = self.create_matplotlib_chart(figsize=(12, 8))
        colors = sns.color_palette("Blues_r", len(author_counts))
        bars = ax.barh(range(len(author_counts)), author_counts.values, color=colors)
        ax.set_yticks(range(len(author_counts)))
        ax.set_yticklabels(author_counts.index)
        ax.invert_yaxis()
        ax.set_xlabel('诗词数量')
        ax.set_title('Top15 高产诗人')
        ax.grid(True, alpha=0.3, axis='x')
        for bar in bars:
            w = bar.get_width()
            ax.text(w + 1, bar.get_y() + bar.get_height() / 2, f'{int(w)}',
                    ha='left', va='center', fontsize=10)
        st.pyplot(fig)

    def show_tag_charts(self):
        """Top15 热门标签"""
        if '标签' not in self.df.columns:
            st.warning("标签数据不可用")
            return

        tag_data = []
        for tags in self.df['标签'].dropna():
            if str(tags).strip():
                tag_data.extend([t.strip() for t in str(tags).split(',') if t.strip()])
        if not tag_data:
            st.warning("没有有效的标签数据")
            return

        tag_counts = pd.Series(tag_data).value_counts().head(15)

        col1, col2 = st.columns(2)
        with col1:
            fig, ax = self.create_matplotlib_chart(figsize=(10, 8))
            colors = sns.color_palette("husl", len(tag_counts))
            ax.barh(range(len(tag_counts)), tag_counts.values, color=colors)
            ax.set_yticks(range(len(tag_counts)))
            ax.set_yticklabels(tag_counts.index)
            ax.invert_yaxis()
            ax.set_xlabel('出现次数')
            ax.set_title('Top15 热门标签')
            ax.grid(True, alpha=0.3, axis='x')
            st.pyplot(fig)

        with col2:
            fig, ax = self.create_matplotlib_chart(figsize=(10, 8))
            ax.pie(tag_counts.values, labels=tag_counts.index,
                   autopct='%1.1f%%', startangle=90, colors=colors)
            ax.set_title('标签占比')
            st.pyplot(fig)

    def show_content_length_charts(self):
        """正文长度：直方图 + 箱线图"""
        if '正文长度' not in self.df.columns:
            st.warning("正文长度数据不可用")
            return

        lengths = self.df['正文长度'][self.df['正文长度'] > 0].dropna()
        if len(lengths) == 0:
            st.warning("没有有效的正文字数数据")
            return

        plot_data = lengths[lengths <= 300]

        col1, col2 = st.columns(2)
        with col1:
            fig, ax = self.create_matplotlib_chart(figsize=(10, 6))
            ax.hist(plot_data, bins=30, color='#2E86AB', alpha=0.75, edgecolor='white')
            ax.set_xlabel('正文字数')
            ax.set_ylabel('诗词数量')
            ax.set_title('正文长度分布（≤300字）')
            ax.grid(True, alpha=0.3)
            st.pyplot(fig)

        with col2:
            fig, ax = self.create_matplotlib_chart(figsize=(10, 6))
            ax.boxplot(lengths, vert=False, patch_artist=True,
                       boxprops=dict(facecolor='#F18F01', alpha=0.7))
            ax.set_xlabel('正文字数')
            ax.set_title('正文长度箱线图')
            ax.grid(True, alpha=0.3)
            st.pyplot(fig)

    def show_dynasty_trend_charts(self):
        """各朝代平均长度趋势"""
        if '朝代' not in self.df.columns or '正文长度' not in self.df.columns:
            st.warning("数据不可用")
            return

        df_filtered = self.df[(self.df['朝代'] != '未知') & (self.df['正文长度'] > 0)]
        if len(df_filtered) == 0:
            st.warning("没有有效数据")
            return

        group = df_filtered.groupby('朝代').agg({
            '正文长度': ['mean', 'count']
        }).round(1)
        group.columns = ['平均长度', '诗词数量']

        order = ['先秦', '两汉', '魏晋', '南北朝', '隋代', '唐代', '五代',
                 '宋代', '金朝', '元代', '明代', '清代']
        ordered = [d for d in order if d in group.index]
        group = group.reindex(ordered)

        if len(group) == 0:
            st.warning("没有有效数据")
            return

        fig, ax1 = self.create_matplotlib_chart(figsize=(12, 6))
        ax1.plot(group.index, group['平均长度'], marker='o', linewidth=2.5,
                 color='#A23B72', label='平均长度', markersize=8)
        ax1.set_xlabel('朝代')
        ax1.set_ylabel('平均正文字数', color='#A23B72')
        ax1.tick_params(axis='y', labelcolor='#A23B72')
        ax1.grid(True, alpha=0.3)
        plt.xticks(rotation=45, ha='right')
        for x, y in zip(group.index, group['平均长度']):
            ax1.annotate(f'{y}', (x, y), textcoords="offset points",
                         xytext=(0, 10), ha='center', fontsize=9)

        ax2 = ax1.twinx()
        ax2.bar(group.index, group['诗词数量'], alpha=0.35,
                color='#2E86AB', label='诗词数量')
        ax2.set_ylabel('诗词数量', color='#2E86AB')
        ax2.tick_params(axis='y', labelcolor='#2E86AB')

        lines1, labels1 = ax1.get_legend_handles_labels()
        lines2, labels2 = ax2.get_legend_handles_labels()
        ax1.legend(lines1 + lines2, labels1 + labels2, loc='upper left')
        ax1.set_title('各朝代诗词数量与平均长度趋势')
        st.pyplot(fig)

    def show_heatmap_charts(self):
        """标签 × 朝代 热力图"""
        if '标签' not in self.df.columns or '朝代' not in self.df.columns:
            st.warning("数据不可用")
            return

        records = []
        for _, row in self.df.iterrows():
            if row['朝代'] == '未知':
                continue
            tags = [t.strip() for t in str(row['标签']).split(',') if t.strip()]
            for tag in tags:
                records.append({'标签': tag, '朝代': row['朝代']})

        if not records:
            st.warning("没有有效数据")
            return

        tag_df = pd.DataFrame(records)
        top_tags = tag_df['标签'].value_counts().head(15).index.tolist()
        order = ['先秦', '两汉', '魏晋', '南北朝', '隋代', '唐代', '五代',
                 '宋代', '金朝', '元代', '明代', '清代']
        present_dynasties = [d for d in order if d in tag_df['朝代'].unique()]
        if len(present_dynasties) < 2:
            st.warning("朝代数据不足")
            return

        filtered = tag_df[tag_df['标签'].isin(top_tags) & tag_df['朝代'].isin(present_dynasties)]
        crosstab = pd.crosstab(filtered['标签'], filtered['朝代'])
        crosstab = crosstab.reindex(index=top_tags)
        crosstab = crosstab.reindex(columns=present_dynasties)
        crosstab = crosstab.fillna(0).astype(int)

        fig, ax = self.create_matplotlib_chart(figsize=(12, 8))
        sns.heatmap(crosstab, annot=True, fmt='d', cmap='YlOrRd', ax=ax,
                    cbar_kws={'label': '诗词数量'}, annot_kws={'size': 9})
        ax.set_title('热门标签与朝代关系热力图')
        ax.set_xlabel('朝代')
        ax.set_ylabel('标签')
        plt.xticks(rotation=45, ha='right')
        st.pyplot(fig)

    def show_author_dynasty_charts(self):
        """Top10 作者所属朝代分布"""
        if '作者' not in self.df.columns or '朝代' not in self.df.columns:
            st.warning("数据不可用")
            return

        author_counts = self.df['作者'].value_counts()
        author_counts = author_counts[author_counts.index != '佚名'].head(10)
        if len(author_counts) == 0:
            st.warning("没有有效数据")
            return

        top_authors = author_counts.index.tolist()
        sub_df = self.df[self.df['作者'].isin(top_authors)]

        crosstab = pd.crosstab(sub_df['作者'], sub_df['朝代'])
        crosstab = crosstab.reindex(index=top_authors).fillna(0).astype(int)

        fig, ax = self.create_matplotlib_chart(figsize=(12, 6))
        bottom = np.zeros(len(crosstab))
        colors = sns.color_palette("Spectral", len(crosstab.columns))
        for i, dynasty in enumerate(crosstab.columns):
            ax.bar(crosstab.index, crosstab[dynasty], bottom=bottom,
                   label=dynasty, color=colors[i], alpha=0.85)
            bottom += crosstab[dynasty].values

        ax.set_xlabel('作者')
        ax.set_ylabel('诗词数量')
        ax.set_title('Top10 高产诗人的朝代分布')
        ax.legend(title='朝代', loc='upper right', fontsize=9)
        ax.grid(True, alpha=0.3, axis='y')
        plt.xticks(rotation=30, ha='right')
        st.pyplot(fig)

    # ==================== 数据洞察 ====================
    def show_insights(self):
        st.markdown('<h2 class="section-header">💡 数据洞察</h2>', unsafe_allow_html=True)
        if not self.stats:
            st.warning("暂无统计数据")
            return

        insights = []

        # 朝代洞察
        if self.stats.get('dynasty_stats'):
            d = self.stats['dynasty_stats']
            top = list(d['distribution'].items())[0]
            insights.append(
                f"🏯 **朝代分析**: 共收录 {d['total_dynasties']} 个朝代的诗词，"
                f"其中 **{top[0]}** 最多，有 {top[1]} 首"
            )

        # 作者洞察
        if self.stats.get('author_stats'):
            a = self.stats['author_stats']
            if a['most_productive_author']:
                insights.append(
                    f"🖋️ **高产诗人**: {a['most_productive_author']} 共收录 "
                    f"{a['most_productive_count']} 首，位居榜首"
                )
            insights.append(
                f"👤 **作者覆盖**: 共收录 {a['total_authors'] - 1} 位诗人，"
                f"另有 {a['anonymous_count']} 首佚名作品"
            )

        # 标签洞察
        if self.stats.get('tag_stats'):
            t = self.stats['tag_stats']
            insights.append(
                f"🏷️ **主题偏好**: 共 {t['total_tags']} 种标签，"
                f"最常见的是 **{t['most_common_tag']}**（{t['most_common_count']} 次）"
            )

        # 正文字数洞察
        if self.stats.get('content_stats'):
            c = self.stats['content_stats']
            insights.append(
                f"📝 **正文分析**: 平均 {c['avg_length']} 字，"
                f"最长 {c['max_length']} 字，最短 {c['min_length']} 字"
            )

        for insight in insights:
            st.info(insight)

        # 额外：Top5 诗人柱状展示
        if self.stats.get('author_stats'):
            st.subheader("🔥 Top10 高产诗人")
            top_authors = dict(list(self.stats['author_stats']['top_authors'].items())[:10])
            st.bar_chart(pd.Series(top_authors))

        # 额外：朝代分布
        if self.stats.get('dynasty_stats'):
            st.subheader("🏯 朝代分布")
            dynasty_dist = self.stats['dynasty_stats']['distribution']
            st.bar_chart(pd.Series(dynasty_dist))

        # 额外：热门标签
        if self.stats.get('tag_stats'):
            st.subheader("🏷️ 热门标签 Top10")
            top_tags = dict(list(self.stats['tag_stats']['top_tags'].items())[:10])
            st.bar_chart(pd.Series(top_tags))


# ==================== 主函数 ====================
def main():
    dashboard = PoetryDashboard()

    with st.sidebar:
        st.title("📜 古诗词数据分析")
        st.divider()
        page_options = {
            "🏠 概览": "overview",
            "🔍 数据探索": "explorer",
            "📊 可视化图表": "charts",
            "💡 数据洞察": "insights"
        }
        selected_page = st.radio(
            "导航菜单",
            list(page_options.keys()),
            index=0
        )
        st.divider()
        st.caption("数据来源: gushici.org")

    if 'page' not in st.session_state:
        st.session_state.page = page_options[selected_page]

    if dashboard.df is None:
        dashboard.load_data()

    page_key = page_options[selected_page]
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

"""
# 方式一（可能弹邮箱提示）
streamlit run app.py

# 方式二（推荐，无邮箱提示）
python -m streamlit run app.py --server.port 8501 --server.headless true
"""