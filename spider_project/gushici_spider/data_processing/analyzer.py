"""
古诗词数据分析及可视化模块
"""
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
import seaborn as sns
from pathlib import Path
import warnings
from typing import Dict, Any
import re

from toml import ordered


# ==================== 中文字体设置 ====================
def setup_chinese_font():
    """设置中文字体，解决中文显示问题"""
    import platform
    system = platform.system()

    if system == 'Windows':
        plt.rcParams['font.sans-serif'] = ['Microsoft YaHei', 'SimHei', 'SimSun']
        plt.rcParams['axes.unicode_minus'] = False
    elif system == 'Darwin':  # macOS系统
        plt.rcParams['font.sans-serif'] = ['Arial Unicode MS', 'PingFang SC', 'Heiti SC']
        plt.rcParams['axes.unicode_minus'] = False
    else:
        plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'WenQuanYi Micro Hei', 'Noto Sans CJK SC']
        plt.rcParams['axes.unicode_minus'] = False

    try:
        font_paths = [
            "C:/Windows/Fonts/msyh.ttc",
            "C:/Windows/Fonts/simhei.ttf",
            "C:/Windows/Fonts/simsun.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/STHeiti Light.ttc",
        ]
        for font_path in font_paths:
            if Path(font_path).exists():
                font_prop = matplotlib.font_manager.FontProperties(fname=font_path)
                matplotlib.rcParams['font.family'] = font_prop.get_name()
                print(f"使用字体: {font_path}")
                break
    except Exception as e:
        print(f"字体设置警告: {e}")
        plt.rcParams['font.sans-serif'] = ['DejaVu Sans']
        plt.rcParams['axes.unicode_minus'] = False

setup_chinese_font()
sns.set_style("whitegrid", {
    'grid_linestyle': '--',
    'grid_alpha': 0.3,
})
warnings.filterwarnings("ignore")

class PoetryAnalyzer:
    """古诗词数据分析器"""
    def __init__(self):
        # 项目根目录
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.cleaned_dir = self.data_dir / "cleaned"
        # 分析结果（Excel）保存到 processed
        self.processed_dir = self.data_dir / "processed"
        # 可视化图表保存到 visualization
        self.visualization_dir = self.data_dir / "visualization"
        # 创建目录（已存在就跳过）
        self.processed_dir.mkdir(parents=True, exist_ok=True)
        self.visualization_dir.mkdir(parents=True, exist_ok=True)

        # 数据文件路径
        self.cleaned_data_path = self.cleaned_dir / "poetry_cleaned.xlsx"
        self.df = None

        # 颜色配置
        self.colors = {
            'primary': '#2E86AB',
            'secondary': '#A23B72',
            'accent': '#F18F01',
            'success': '#3CBBB1',
            'warning': '#F26419',
            'background': '#F5F5F5'
        }
        self.font_props = {
            'title': {'fontsize': 16, 'fontweight': 'bold'},
            'axis': {'fontsize': 12},
            'label': {'fontsize': 11},
            'legend': {'fontsize': 10}
        }

        # 朝代顺序（用于图表按时间排序）
        self.dynasty_order = [
            '先秦', '两汉', '魏晋', '南北朝', '隋代', '唐代', '五代',
            '宋代', '金朝', '元代', '明代', '清代', '近代', '现代', '当代', '未知'
        ]

    # ==================== 加载数据 ====================
    def load_data(self) -> bool:
        """加载清洗后的数据"""
        try:
            if self.cleaned_data_path.exists():
                self.df = pd.read_excel(self.cleaned_data_path)
                print(f"数据加载成功: {len(self.df)} 首诗词")
            else:
                csv_path = self.cleaned_data_path.with_suffix('.csv')
                if csv_path.exists():
                    self.df = pd.read_csv(csv_path, encoding='utf-8-sig')
                    print(f"数据加载成功: {len(self.df)} 首诗词")
                else:
                    print("未找到清洗后的数据文件，请先运行数据清洗")
                    return False

            # 派生字段：正文长度（用于后续统计分析）
            if '正文' in self.df.columns:
                self.df['正文长度'] = self.df['正文'].fillna('').astype(str).str.len()
            # 确保标签是字符串
            if '标签' in self.df.columns:
                self.df['标签'] = self.df['标签'].fillna('').astype(str)
            return True
        except Exception as e:
            print(f"数据加载失败: {e}")
            return False

    # ==================== 基础统计 ====================
    def basic_statistics(self) -> Dict[str, Any]:
        """基础统计分析"""
        if self.df is None:
            return {}

        stats = {
            'total_poems': len(self.df),
            'dynasty_stats': {},
            'author_stats': {},
            'tag_stats': {},
            'content_stats': {}
        }

        # 朝代分布
        if '朝代' in self.df.columns:
            dynasty_counts = self.df['朝代'].value_counts().to_dict()
            stats['dynasty_stats'] = {
                'total_dynasties': len(dynasty_counts),
                'distribution': dynasty_counts,
                'top_dynasty': list(dynasty_counts.keys())[0] if dynasty_counts else '',
            }

        # 作者统计
        if '作者' in self.df.columns:
            author_counts = self.df['作者'].value_counts()
            # 排除"佚名"
            real_author_counts = author_counts[author_counts.index != '佚名']
            stats['author_stats'] = {
                'total_authors': len(author_counts),
                'anonymous_count': int((self.df['作者'] == '佚名').sum()),
                'top_authors': real_author_counts.head(15).to_dict(),
                'most_productive_author': real_author_counts.index[0] if len(real_author_counts) > 0 else '',
                'most_productive_count': int(real_author_counts.iloc[0]) if len(real_author_counts) > 0 else 0,
            }

        # 标签统计
        if '标签' in self.df.columns:
            tag_data = self._flatten_tags(self.df['标签'])
            if tag_data:
                tag_counts = pd.Series(tag_data).value_counts()
                stats['tag_stats'] = {
                    'total_tags': len(tag_counts),
                    'top_tags': tag_counts.head(15).to_dict(),
                    'most_common_tag': tag_counts.index[0],
                    'most_common_count': int(tag_counts.iloc[0]),
                }

        # 正文长度统计
        if '正文长度' in self.df.columns:
            valid = self.df['正文长度'][self.df['正文长度'] > 0]
            if len(valid) > 0:
                stats['content_stats'] = {
                    'avg_length': round(valid.mean(), 1),
                    'median_length': round(valid.median(), 1),
                    'max_length': int(valid.max()),
                    'min_length': int(valid.min()),
                }

        return stats

    def _flatten_tags(self, tag_series) -> list:
        """把逗号分隔的标签列展开成一个大列表"""
        result = []
        for tags in tag_series:
            if pd.notna(tags) and str(tags).strip():
                for t in str(tags).split(','):
                    t = t.strip()
                    if t:
                        result.append(t)
        return result


    # ==================== 图表 1：朝代分布 ====================
    def create_dynasty_distribution_plot(self):
        """朝代分布图（柱状图 + 饼图）"""
        if self.df is None or "朝代" not in self.df.columns:
            return

        dynasty_counts = self.df['朝代'].value_counts()
        # 排除"未知"
        dynasty_counts = dynasty_counts[dynasty_counts.index != '未知']

        # 按朝代时间顺序排序
        ordered = [d for d in self.dynasty_order if d in dynasty_counts.index]
        dynasty_counts = dynasty_counts.reindex(ordered)

        if len(dynasty_counts) == 0:
            return

        fig, (ax1, ax2) = plt.subplots(1,2,figsize=(16,7))

        # 左图 : 柱状图
        colors = sns.color_palette("Spectral", n_colors=len(dynasty_counts))
        bars = ax1.bar(dynasty_counts.index, dynasty_counts.values, color=colors, alpha=0.85)
        ax1.set_xlabel('朝代', fontproperties='SimHei', fontsize=12)
        ax1.set_ylabel('诗词数量', fontproperties='SimHei', fontsize=12)
        ax1.set_title('各朝代诗词数量分布', fontproperties='SimHei', fontsize=14, fontweight='bold')
        ax1.tick_params(labelsize=10)
        ax1.grid(True, alpha=0.3, axis='y')

        # 在柱子上标数值
        for bar in bars:
            h = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width() / 2, h + 2, f'{int(h)}',
                     ha='center', va='bottom', fontsize=9)

        # 右图 : 饼图
        wedges, texts, autotexts = ax2.pie(
            dynasty_counts.values,
            labels=dynasty_counts.index,
            autopct='%1.1f%%',
            startangle=90,
            colors=colors,
        )
        for text in texts:
            text.set_fontproperties('SimHei')
            text.set_fontsize(10)
        for autotext in autotexts:
            autotext.set_fontproperties('SimHei')
            autotext.set_fontsize(9)
        ax2.set_title("朝代占比", fontproperties='SimHei', fontsize=14, fontweight='bold')

        plt.tight_layout()
        plt.savefig(self.visualization_dir / 'dynasty_distribution.png',
                    dpi=300, bbox_inches='tight',facecolor='white')
        plt.show()

    # ==================== 图表 2：高产作者 ====================
    def create_top_authors_plot(self):
        """Top15 高产诗人"""
        if self.df is None or '作者' not in self.df.columns:
            return

        author_counts = self.df['作者'].value_counts()
        # 排除佚名
        author_counts = author_counts[author_counts.index != '佚名'].head(15)

        if len(author_counts) == 0:
            return

        fig, ax = plt.subplots(figsize=(12, 8))

        colors = sns.color_palette("Blues_r", len(author_counts))
        bars = ax.barh(range(len(author_counts)), author_counts.values, color=colors)
        ax.set_yticks(range(len(author_counts)))
        ax.set_yticklabels(author_counts.index, fontproperties='SimHei', fontsize=11)
        ax.invert_yaxis()  # 高产诗人放最上
        ax.set_xlabel('诗词数量', fontproperties='SimHei', fontsize=12)
        ax.set_title('Top15 高产诗人', fontproperties='SimHei', fontsize=14, fontweight='bold')
        ax.tick_params(labelsize=10)
        ax.grid(True, alpha=0.3, axis='x')

        # 条形右端标数值
        for bar in bars:
            w = bar.get_width()
            ax.text(w + 1, bar.get_y() + bar.get_height() / 2, f'{int(w)}',
                    ha='left', va='center', fontsize=10)

        plt.tight_layout()
        plt.savefig(self.visualization_dir / 'top_authors.png',
                    dpi=300, bbox_inches='tight', facecolor='white')
        plt.show()

    # ==================== 图表 3：标签分布 ====================
    def create_tag_distribution_plot(self):
        """Top15 标签分布（条形图 + 饼图）"""
        if self.df is None or '标签' not in self.df.columns:
            return

        tag_data = self._flatten_tags(self.df['标签'])
        if not tag_data:
            return

        tag_counts = pd.Series(tag_data).value_counts().head(15)
        if len(tag_counts) == 0:
            return

        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))

        # 左图：水平条形图
        colors = sns.color_palette("husl", len(tag_counts))
        ax1.barh(range(len(tag_counts)), tag_counts.values, color=colors)
        ax1.set_yticks(range(len(tag_counts)))
        ax1.set_yticklabels(tag_counts.index, fontproperties='SimHei', fontsize=10)
        ax1.invert_yaxis()
        ax1.set_xlabel('出现次数', fontproperties='SimHei', fontsize=12)
        ax1.set_title('Top15 热门标签', fontproperties='SimHei', fontsize=14, fontweight='bold')
        ax1.tick_params(labelsize=10)
        ax1.grid(True, alpha=0.3, axis='x')

        # 右图：饼图
        wedges, texts, autotexts = ax2.pie(
            tag_counts.values,
            labels=tag_counts.index,
            autopct='%1.1f%%',
            startangle=90,
            colors=colors
        )
        for text in texts:
            text.set_fontproperties('SimHei')
            text.set_fontsize(9)
        for autotext in autotexts:
            autotext.set_fontproperties('SimHei')
            autotext.set_fontsize(8)
        ax2.set_title('标签占比', fontproperties='SimHei', fontsize=14, fontweight='bold')

        plt.tight_layout()
        plt.savefig(self.visualization_dir / 'tag_distribution.png',
                    dpi=300, bbox_inches='tight', facecolor='white')
        plt.show()

    # ==================== 图表 4：正文长度分析 ====================
    def create_content_length_plot(self):
        """正文长度分布（直方图 + 箱线图）"""
        if self.df is None or '正文长度' not in self.df.columns:
            return

        lengths = self.df['正文长度'][self.df['正文长度'] > 0].dropna()
        if len(lengths) == 0:
            return

        # 过滤极端值（>300字）避免影响视觉
        plot_data = lengths[lengths <= 300]

        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))

        # 左图：直方图
        ax1.hist(plot_data, bins=30, color=self.colors['primary'],
                 alpha=0.75, edgecolor='white')
        ax1.set_xlabel('正文字数', fontproperties='SimHei', fontsize=12)
        ax1.set_ylabel('诗词数量', fontproperties='SimHei', fontsize=12)
        ax1.set_title('正文长度分布（≤300字）', fontproperties='SimHei',
                      fontsize=14, fontweight='bold')
        ax1.tick_params(labelsize=10)
        ax1.grid(True, alpha=0.3)

        # 右图：箱线图
        ax2.boxplot(lengths, vert=False, patch_artist=True,
                    boxprops=dict(facecolor=self.colors['accent'], alpha=0.7))
        ax2.set_xlabel('正文字数', fontproperties='SimHei', fontsize=12)
        ax2.set_title('正文长度箱线图', fontproperties='SimHei',
                      fontsize=14, fontweight='bold')
        ax2.tick_params(labelsize=10)
        ax2.grid(True, alpha=0.3)

        plt.tight_layout()
        plt.savefig(self.visualization_dir / 'content_length_analysis.png',
                    dpi=300, bbox_inches='tight', facecolor='white')
        plt.show()


    # ==================== 图表 5：各朝代平均长度趋势 ====================
    def create_dynasty_length_trend_plot(self):
        """各朝代诗词平均长度和数量趋势"""
        if self.df is None or '朝代' not in self.df.columns or '正文长度' not in self.df.columns:
            return

        # 排除未知朝代和空正文
        df_filtered = self.df[(self.df['朝代'] != '未知') & (self.df['正文长度'] > 0)]
        if len(df_filtered) == 0:
            return

        # 按朝代分组
        group = df_filtered.groupby('朝代').agg({
            '正文长度': ['mean', 'count']
        }).round(1)
        group.columns = ['平均长度', '诗词数量']

        # 按朝代时间排序
        ordered = [d for d in self.dynasty_order if d in group.index]
        group = group.reindex(ordered)

        if len(group) == 0:
            return

        fig, ax1 = plt.subplots(figsize=(14, 7))

        # 左 Y 轴：平均长度折线
        ax1.plot(group.index, group['平均长度'], marker='o', linewidth=2.5,
                 color=self.colors['secondary'], label='平均长度', markersize=8)
        ax1.set_xlabel('朝代', fontproperties='SimHei', fontsize=12)
        ax1.set_ylabel('平均正文字数', fontproperties='SimHei', fontsize=12,
                       color=self.colors['secondary'])
        ax1.tick_params(axis='y', labelcolor=self.colors['secondary'], labelsize=10)
        ax1.tick_params(axis='x', labelsize=10)
        ax1.grid(True, alpha=0.3)

        # 在每个数据点上标注数值
        for x, y in zip(group.index, group['平均长度']):
            ax1.annotate(f'{y}', (x, y), textcoords="offset points",
                         xytext=(0, 10), ha='center', fontsize=9)

        # 右 Y 轴：诗词数量柱状
        ax2 = ax1.twinx()
        ax2.bar(group.index, group['诗词数量'], alpha=0.35,
                color=self.colors['primary'], label='诗词数量')
        ax2.set_ylabel('诗词数量', fontproperties='SimHei', fontsize=12,
                       color=self.colors['primary'])
        ax2.tick_params(axis='y', labelcolor=self.colors['primary'], labelsize=10)

        # 合并图例
        lines1, labels1 = ax1.get_legend_handles_labels()
        lines2, labels2 = ax2.get_legend_handles_labels()
        ax1.legend(lines1 + lines2, labels1 + labels2,
                   loc='upper left', prop={'family': 'SimHei', 'size': 10})

        plt.title('各朝代诗词数量与平均长度趋势', fontproperties='SimHei',
                  fontsize=14, fontweight='bold')
        plt.tight_layout()
        plt.savefig(self.visualization_dir / 'dynasty_length_trend.png',
                    dpi=300, bbox_inches='tight', facecolor='white')
        plt.show()


    # ==================== 图表 6：标签 × 朝代 热力图 ====================
    def create_tag_dynasty_heatmap(self):
        """热门标签在各朝代的分布热力图"""
        if self.df is None or '标签' not in self.df.columns or '朝代' not in self.df.columns:
            return

        # 展开成 (标签, 朝代) 记录
        records = []
        for _, row in self.df.iterrows():
            if row['朝代'] == '未知':
                continue
            tags = [t.strip() for t in str(row['标签']).split(',') if t.strip()]
            for tag in tags:
                records.append({'标签': tag, '朝代': row['朝代']})

        if not records:
            return

        tag_df = pd.DataFrame(records)
        # Top 15 标签
        top_tags = tag_df['标签'].value_counts().head(15).index.tolist()
        # 只保留有数据的朝代，按时间顺序
        present_dynasties = [d for d in self.dynasty_order if d in tag_df['朝代'].unique()]
        if len(present_dynasties) < 2:
            return

        filtered = tag_df[tag_df['标签'].isin(top_tags) & tag_df['朝代'].isin(present_dynasties)]
        crosstab = pd.crosstab(filtered['标签'], filtered['朝代'])
        crosstab = crosstab.reindex(index=top_tags)
        crosstab = crosstab.reindex(columns=present_dynasties)
        crosstab = crosstab.fillna(0).astype(int)

        fig, ax = plt.subplots(figsize=(14, 9))
        sns.heatmap(crosstab, annot=True, fmt='d', cmap='YlOrRd',
                    ax=ax, cbar_kws={'label': '诗词数量'},
                    annot_kws={'size': 10})
        ax.set_title('热门标签与朝代关系热力图', fontproperties='SimHei',
                     fontsize=14, fontweight='bold')
        ax.set_xlabel('朝代', fontproperties='SimHei', fontsize=12)
        ax.set_ylabel('标签', fontproperties='SimHei', fontsize=12)
        ax.set_xticklabels(ax.get_xticklabels(), fontproperties='SimHei', fontsize=10)
        ax.set_yticklabels(ax.get_yticklabels(), fontproperties='SimHei', fontsize=10)

        plt.tight_layout()
        plt.savefig(self.visualization_dir / 'tag_dynasty_heatmap.png',
                    dpi=300, bbox_inches='tight', facecolor='white')
        plt.show()


    # ==================== 图表 7：作者朝代分布 ====================
    def create_author_dynasty_analysis(self):
        """Top10 作者所属朝代分布"""
        if self.df is None or '作者' not in self.df.columns or '朝代' not in self.df.columns:
            return

        # 取 Top10 作者（排除佚名）
        author_counts = self.df['作者'].value_counts()
        author_counts = author_counts[author_counts.index != '佚名'].head(10)
        if len(author_counts) == 0:
            return

        top_authors = author_counts.index.tolist()
        sub_df = self.df[self.df['作者'].isin(top_authors)]

        # 交叉表：作者 × 朝代
        crosstab = pd.crosstab(sub_df['作者'], sub_df['朝代'])
        crosstab = crosstab.reindex(index=top_authors).fillna(0).astype(int)

        fig, ax = plt.subplots(figsize=(14, 7))
        # 堆叠柱状图
        bottom = np.zeros(len(crosstab))
        colors = sns.color_palette("Spectral", len(crosstab.columns))
        for i, dynasty in enumerate(crosstab.columns):
            ax.bar(crosstab.index, crosstab[dynasty], bottom=bottom,
                   label=dynasty, color=colors[i], alpha=0.85)
            bottom += crosstab[dynasty].values

        ax.set_xlabel('作者', fontproperties='SimHei', fontsize=12)
        ax.set_ylabel('诗词数量', fontproperties='SimHei', fontsize=12)
        ax.set_title('Top10 高产诗人的朝代分布', fontproperties='SimHei',
                     fontsize=14, fontweight='bold')
        ax.tick_params(labelsize=10)
        ax.set_xticklabels(crosstab.index, rotation=30, ha='right', fontproperties='SimHei')
        ax.legend(title='朝代', prop={'family': 'SimHei', 'size': 9},
                  loc='upper right')
        ax.grid(True, alpha=0.3, axis='y')

        plt.tight_layout()
        plt.savefig(self.visualization_dir / 'author_dynasty_analysis.png',
                    dpi=300, bbox_inches='tight', facecolor='white')
        plt.show()



    # ==================== 文字报告 ====================
    def create_comprehensive_report(self):
        """创建综合分析报告（控制台打印）"""
        if self.df is None:
            print("没有数据可供分析")
            return

        print("=" * 60)
        print("古诗词数据分析报告")
        print("=" * 60)

        stats = self.basic_statistics()
        print(f"\n📊 基础统计信息:")
        print(f"   诗词总数: {stats['total_poems']} 首")

        if stats['dynasty_stats']:
            print(f"\n🏯 朝代分析:")
            print(f"   涉及朝代: {stats['dynasty_stats']['total_dynasties']} 个")
            print("   主要朝代分布 (Top5):")
            for dynasty, count in list(stats['dynasty_stats']['distribution'].items())[:5]:
                print(f"     {dynasty}: {count} 首")

        if stats['author_stats']:
            print(f"\n🖋️  作者分析:")
            print(f"   涉及作者: {stats['author_stats']['total_authors']} 位")
            print(f"   佚名作品: {stats['author_stats']['anonymous_count']} 首")
            if stats['author_stats']['most_productive_author']:
                print(f"   最高产诗人: {stats['author_stats']['most_productive_author']} "
                      f"({stats['author_stats']['most_productive_count']} 首)")
            print("   高产诗人 (Top5):")
            for author, count in list(stats['author_stats']['top_authors'].items())[:5]:
                print(f"     {author}: {count} 首")

        if stats['tag_stats']:
            print(f"\n🏷️  标签分析:")
            print(f"   涉及标签: {stats['tag_stats']['total_tags']} 种")
            print(f"   最常见标签: {stats['tag_stats']['most_common_tag']} "
                  f"({stats['tag_stats']['most_common_count']} 次)")
            print("   热门标签 (Top5):")
            for tag, count in list(stats['tag_stats']['top_tags'].items())[:5]:
                print(f"     {tag}: {count} 次")

        if stats['content_stats']:
            print(f"\n📝 正文分析:")
            print(f"   平均字数: {stats['content_stats']['avg_length']} 字")
            print(f"   中位字数: {stats['content_stats']['median_length']} 字")
            print(f"   最长: {stats['content_stats']['max_length']} 字")
            print(f"   最短: {stats['content_stats']['min_length']} 字")

        print(f"\n💾 分析结果将保存到: {self.processed_dir}")
        print(f"📈 可视化图表将保存到: {self.visualization_dir}")
        print("=" * 60)

    # ==================== 导出 Excel ====================
    def export_analysis_results(self):
        """导出分析结果到 Excel（保存到 processed 文件夹）"""
        if self.df is None:
            return

        output_path = self.processed_dir / 'poetry_analysis.xlsx'
        with pd.ExcelWriter(output_path, engine='openpyxl', mode='w') as writer:
            # Sheet1: 清洗后的全量数据
            self.df.to_excel(writer, sheet_name='原始数据', index=False)

            # Sheet2: 朝代统计
            if '朝代' in self.df.columns:
                dynasty_stats = self.df.groupby('朝代').agg({
                    '标题': 'count',
                    '正文长度': ['mean', 'max', 'min']
                }).round(1)
                dynasty_stats.columns = ['诗词数量', '平均字数', '最长字数', '最短字数']
                # 按时间顺序
                ordered = [d for d in self.dynasty_order if d in dynasty_stats.index]
                dynasty_stats = dynasty_stats.reindex(ordered)
                dynasty_stats.to_excel(writer, sheet_name='朝代统计')

            # Sheet3: 作者统计
            if '作者' in self.df.columns:
                author_stats = self.df.groupby('作者').agg({
                    '标题': 'count',
                    '正文长度': 'mean'
                }).round(1)
                author_stats.columns = ['诗词数量', '平均字数']
                author_stats = author_stats.sort_values('诗词数量', ascending=False)
                author_stats.to_excel(writer, sheet_name='作者统计')

            # Sheet4: 标签统计
            if '标签' in self.df.columns:
                tag_data = self._flatten_tags(self.df['标签'])
                if tag_data:
                    tag_series = pd.Series(tag_data)
                    tag_stats = tag_series.value_counts().reset_index()
                    tag_stats.columns = ['标签', '出现次数']
                    tag_stats.to_excel(writer, sheet_name='标签统计', index=False)

            # Sheet5: 长度分布（按区间）
            if '正文长度' in self.df.columns:
                bins = [0, 20, 40, 60, 80, 100, 200, 1000]
                labels = ['0-20', '21-40', '41-60', '61-80', '81-100', '101-200', '200+']
                length_bins = pd.cut(self.df['正文长度'], bins=bins, labels=labels, right=True)
                length_dist = length_bins.value_counts().sort_index().reset_index()
                length_dist.columns = ['字数区间', '诗词数量']
                length_dist.to_excel(writer, sheet_name='长度分布', index=False)

        print(f"详细分析结果已导出到: {output_path}")


    # ==================== 主流程 ====================
    def run_all_analysis(self):
        """运行所有分析"""
        print("=" * 60)
        print("开始运行古诗词数据全面分析")
        print("=" * 60)

        if not self.load_data():
            print("数据加载失败，请检查数据文件")
            return

        print("\n1. 生成基础统计报告...")
        self.create_comprehensive_report()

        print("\n2. 生成朝代分布图...")
        self.create_dynasty_distribution_plot()

        print("\n3. 生成高产诗人图...")
        self.create_top_authors_plot()

        print("\n4. 生成标签分布图...")
        self.create_tag_distribution_plot()

        print("\n5. 生成正文长度分析图...")
        self.create_content_length_plot()

        print("\n6. 生成朝代长度趋势图...")
        self.create_dynasty_length_trend_plot()

        print("\n7. 生成标签×朝代热力图...")
        self.create_tag_dynasty_heatmap()

        print("\n8. 生成作者朝代分布图...")
        self.create_author_dynasty_analysis()

        print("\n9. 导出分析结果到Excel...")
        self.export_analysis_results()

        print("\n" + "=" * 60)
        print("🎉 所有分析完成！")
        print(f"📊 分析结果: {self.processed_dir}")
        print(f"📈 可视化图表: {self.visualization_dir}")
        print("=" * 60)



# ==================== 主程序入口 ====================
def main():
    import sys
    analyzer = PoetryAnalyzer()

    if len(sys.argv) > 1:
        if sys.argv[1] == '--quick':
            analyzer.load_data()
            analyzer.create_comprehensive_report()
        elif sys.argv[1] == '--full':
            analyzer.run_all_analysis()
        else:
            print("使用方法:")
            print("  python data_processing/analyzer.py              # 完整分析")
            print("  python data_processing/analyzer.py --quick      # 快速分析（仅文字报告）")
            print("  python data_processing/analyzer.py --full       # 完整分析")
    else:
        analyzer.run_all_analysis()


if __name__ == "__main__":
    setup_chinese_font()
    main()