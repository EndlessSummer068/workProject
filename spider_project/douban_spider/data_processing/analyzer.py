"""
豆瓣电影数据分析及可视化模块
"""
# 数据分析库
import pandas as pd
# 数据计算库
import numpy as np
# 数据可视化库
import matplotlib as plt
# 高级数据可视化库
# （内置非常美观的默认主题和调色板）
import seaborn as sns
# 路径操作
from pathlib import Path
import warnings
# 从类型提示模块导入字典、列表、元组、任意类型等数据类型标签
# 用来给代码指定不同的类型
from typing import Dict,Any
import re
import matplotlib



# 设置中文字体的完整方案
def setup_chinese_font():
    """设置中文字体，解决中文显示问题"""
    # 获取当前运行代码的操作系统和硬件环境信息
    import platform
    import os
    # 系统
    system = platform.system()

    if system == 'Windows':
        # plt.rcParams 是Matplotlib的全局参数字典，控制图表的默认样式和属性
        # font.sans-serif 代表“无衬线字体”（Matplotlib会优先，从这个列表里，寻找字体来渲染文本）
        # 三种常见字体：微软雅黑、黑体、宋体
        plt.rcParams['font.sans-serif'] = ['Microsoft YaHei', 'SimHei', 'SimSun']
        # 解决Matplotlib在显示负数时，负号（-）变成方块或乱码的问题
        # （Matplotlib将坐标轴上，负号渲染为Unicode减号）
        # （False表示不要使用Unicode减号，而是使用键盘上的减号，这样的减号就能显示正常了）
        plt.rcParams['axes.unicode_minus'] = False
    elif system == 'Darwin':   # macOS系统
        # Unicode字体，苹方-简，华文黑体
        plt.rcParams['font.sans-serif'] = ['Arial Unicode MS', 'PingFang SC', 'Heiti SC']
        plt.rcParams['axes.unicode_minus'] = False
    else:  # Linux系统
        # 英文无衬线字体，文泉驿微米黑，思源黑体
        plt.rcParams['font.sans-serif'] = ['DejaVu Sans','WenQuanYi Micro Hei','Noto Sans CJK SC']
        plt.rcParams['axes.unicode_minus'] = False

    # 尝试更可靠的中文字体配置
    try:
        # 方法1：通过绝对路径指定字体（本地c盘的fonts文件夹下，需要有这些字体存在）
        font_paths = [
            "C:/Windows/Fonts/msyh.ttc",  # 微软雅黑
            "C:/Windows/Fonts/simhei.ttf",  # 黑体
            "C:/Windows/Fonts/simsun.ttc",  # 宋体
            "/System/Library/Fonts/PingFang.ttc",  # macOS
            "/System/Library/Fonts/STHeiti Light.ttc",  # macOS
        ]
        for font_path in font_paths:
            if Path(font_path).exists():
                # font_manager 查找、管理和使用各种字体
                # FontProperties 存储和控制字体属性的类
                # fname=font_path 直接传入一个.ttf或.otf字体文件的路径（不只是c盘字体）
                font_prop = matplotlib.font_manager.FontProperties(fname=font_path)
                # 将本地字体文件（fname）加载的自定义字体，动态提取出它的内部名称，将其设置为Matplotlib的全局默认字体
                matplotlib.rcParams['font.family'] = font_prop.get_name()
                print(f"使用字体: {font_path}")
                break
    except Exception as e:
        print(f"字体设置警告: {e}")
        # 备用方案
        # 英文无衬线字体
        plt.rcParams['font.sans-serif'] = ['DejaVu Sans']
        plt.rcParams['axes.unicode_minus'] = False

# 应用字体设置
setup_chinese_font()

# 设置Seaborn风格的绘图样式
sns.set_style("whitegrid", {
    'grid.linestyle': '--',   # 网格线的线型为虚线
    'grid.alpha': 0.3   # 网格线的透明度为30%
})
# 全局静默，Python运行过程中，产生的所有警告信息（Warnings），不在控制台输出
# filterwarnings 警告过滤器
# ignore 遇到警告直接忽略，不要打印到控制台
warnings.filterwarnings("ignore")

class DouBanAnalyzer:
    """豆瓣电影数据分析器"""
    def __init__(self):
        # 项目根目录
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.cleaned_dir = self.data_dir / "cleaned"
        self.results_dir = self.data_dir / "results"
        # parents=True 创建递归目录的开关（路径中包含多级不存在的父目录，会自动一层层把它们全建出来）
        # exist_ok=True 创建目录时，如果该文件夹已经存在了，程序会直接跳过，不会报错
        # 数据文件路径
        self.cleaned_data_path = self.cleaned_dir / "douban_movies_cleaned.xlsx"
        self.df = None
        # 颜色配置
        self.colors = {
            'primary': '#2E86AB',  # 蓝色
            'secondary': '#A23B72',  # 紫红色
            'accent': '#F18F01',  # 橙色
            'success': '#3CBBB1',  # 青绿色
            'warning': '#F26419',  # 红橙色
            'background': '#F5F5F5'  # 灰色
        }
        # 额外的字体设置
        self.font_props = {
            'title': {'fontsize': 16, 'fontweight': 'bold'},  # 标题：字号16，加粗
            'axis': {'fontsize': 12},  # 坐标轴刻度：字号12
            'label': {'fontsize': 11},  # 轴标签：字号11
            'legend': {'fontsize': 10}  # 图例：字号10
        }

    def load_data(self) -> bool:
        """加载清洗后的数据"""
        try:
            if self.cleaned_data_path.exists():
                # 将本地指定路径的Excel文件，读取并转换为DataFrame数据结构
                self.df = pd.read_excel(self.cleaned_data_path)
                print(f"数据加载成功: {len(self.df)} 部电影")
                # 检查并转换评分列
                if '评分' in self.df.columns:
                    # to_numeric() -- 将数据转换为数值类型
                    # errors='coerce' 遇到无法转换为数字的值时，将其转换为NaN
                    self.df['评分'] = pd.to_numeric(self.df['评分'], errors='coerce')
                # 检查并转换评价人数列（对评价人数列进行清洗和转换）
                if '评价人数' in self.df.columns:
                    # 去掉中文单位 -- 人评价（例如：15.2万人评价）
                    # astype() -- 强制类型转换（将评价人数，这一列的所有元素，都变成字符串类型）
                    # .str -- 把这一列当作一整块文本来处理，就可以直接调用各种内置的字符串方法了
                    # replace('人评价','',regex=False) 将 人评价 替换为 空白，且关闭正则表达式模式
                    self.df['评价人数'] = self.df['评价人数'].astype(str).str.replace('人评价', '', regex=False)
                    # 继续去掉千分位逗号（例如：15,200）
                    self.df['评价人数'] = self.df['评价人数'].astype(str).str.replace(',', '')
                    # 继续转换为数值类型
                    self.df['评价人数'] = pd.to_numeric(self.df['评价人数'], errors='coerce')
                return True
            else:
                # 尝试加载CSV格式
                # 获取self.cleaned_data_path这个路径对象，并把它的文件后缀名替换为.csv
                # with_suffix() -- 返回一个新的路径对象，原路径不变，只是后缀被换成了.csv
                csv_path = self.cleaned_data_path.with_suffix('.csv')
                if csv_path.exists():
                    # 读取指定路径的CSV文件，并返回一个DataFrame
                    # 为什么要特意用utf-8-sig而不是普通的utf-8？
                    # 用Excel保存CSV文件，Excel默认会在文件开头，偷偷塞入一个不可见的BOM头（\xef\xbb\xbf）
                    # 普通utf-8读取，会把BOM头当成第一列列名的一部分，导致第一列名字看起来像'\ufeff姓名'，后续处理非常容易报错
                    # 用utf-8-sig读取，会自动识别并忽略掉这个BOM头，完美拿到真实列名
                    self.df = pd.read_csv(csv_path, encoding='utf-8-sig')
                    print(f"数据加载成功: {len(self.df)} 部电影")
                    # 同样的数据清洗
                    if '评分' in self.df.columns:
                        self.df['评分'] = pd.to_numeric(self.df['评分'], errors='coerce')
                    if '评价人数' in self.df.columns:
                        self.df['评价人数'] = self.df['评价人数'].astype(str).str.replace('人评价', '', regex=False)
                        self.df['评价人数'] = self.df['评价人数'].astype(str).str.replace(',', '')
                        self.df['评价人数'] = pd.to_numeric(self.df['评价人数'], errors='coerce')
                    return True
                else:
                    print("未找到清洗后的数据文件，请先运行数据清洗")
                    return False
        except Exception as e:
            print(f"数据加载失败: {e}")
            return False
    # 返回字典数据类型，其中键是字符串，值是任意数据类型
    def basic_statistics(self) -> Dict[str, Any]:
        """基础统计分析"""
        if self.df is None:
            return {}
        stats = {
            'total_movies': len(self.df),  # 电影总数
            'time_range': {},  # 上映时间范围
            'rating_stats': {},  # 电影评分统计
            'vote_stats': {},  # 评价人数统计
            'country_distribution': {},  # 国家/地区分布
            'genre_distribution': {},  # 电影类型分布
            'director_stats': {},  # 导演统计
            'actor_stats': {}  # 演员统计
        }
        # 时间范围分析
        if '上映年份' in self.df.columns:
            year_series = pd.to_numeric(self.df['上映年份'], errors='coerce')
            # dropna()：删除缺失值
            valid_years = year_series.dropna()
            if len(valid_years) > 0:
                # 上映时间范围
                stats['time_range'] = {
                    'min_year': int(valid_years.min()),  # 年份最小值
                    'max_year': int(valid_years.max()),  # 年份最大值
                    'year_span': int(valid_years.max() - valid_years.min()),  # 年份跨度
                    'avg_year': int(valid_years.mean())  # 年份平均值（向下取整）
                }
        # 评分统计
        if '评分' in self.df.columns:
            # 电影评分统计
            stats['rating_stats'] = {
                'mean_rating': round(self.df['评分'].mean(), 2),  # 平均评分
                'median_rating': round(self.df['评分'].median(), 2),  # 中位评分
                'max_rating': round(self.df['评分'].max(), 2),  # 最高评分
                'min_rating': round(self.df['评分'].min(), 2),  # 最低评分
                'std_rating': round(self.df['评分'].std(), 2)  # 评分标准差
            }
        # 评价人数统计
        if '评价人数' in self.df.columns:
            stats['vote_stats'] = {
                'total_votes': int(self.df['评价人数'].sum()),
                'mean_votes': int(self.df['评价人数'].mean()),
                'max_votes': int(self.df['评价人数'].max()),
                'min_votes': int(self.df['评价人数'].min())
            }
        # 国家地区分布
        if '国家地区' in self.df.columns:
            # 面向对象封装的写法
            # 这里的self指当前类
            country_stats = self._analyze_country_distribution()
            stats['country_distribution'] = country_stats
        # 电影类型分布
        if '电影类型' in self.df.columns:
            genre_stats = self._analyze_genre_distribution()
            stats['genre_distribution'] = genre_stats
        # 导演分析
        if '导演' in self.df.columns:
            director_stats = self._analyze_director_stats()
            stats['director_stats'] = director_stats
        # 演员分析
        if '演员' in self.df.columns:
            actor_stats = self._analyze_actor_stats()
            stats['actor_stats'] = actor_stats
        return stats

    def _analyze_country_distribution(self) -> Dict[str, Any]:
        """分析国家地区分布"""
        country_data = []
        for countries in self.df['国家地区']:
            if pd.notna(countries) and str(countries) != '未知':
                country_list = [c.strip() for c in countries.split('/')]
                country_data.extend(country_list)
        # 将country_data转换成Series对象
        country_series = pd.Series(country_data)
        # 统计国家/地区出现的次数
        country_counts = country_series.value_counts()
        return {
            # 提取前10个国家/地区并转为字典
            # to_dict将Series对象转为字典
            'top_countries': country_counts.head(10).to_dict(),
            # 统计国家/地区总数
            'total_countries': len(country_counts),
            # 统计合拍电影数量
            # notna() 判断当前值是不是空值
            'co_production_movies': len([c for c in self.df['国家地区'] if pd.notna(c) and '/' in str(c)])
        }

    def _analyze_genre_distribution(self) -> Dict[str, Any]:
        """分析电影类型分布"""
        genre_data = []
        for genres in self.df['电影类型']:
            if pd.notna(genres) and str(genres) != '未知':
                genre_list = [g.strip() for g in str(genres).split('/')]
                genre_data.extend(genre_list)
        genre_series = pd.Series(genre_data)
        genre_counts = genre_series.value_counts()
        return {
            'top_genres': genre_counts.head(10).to_dict(),
            'total_genres': len(genre_counts),
            'mixed_genres_movies': len([g for g in self.df['电影类型']
                                        if pd.notna(g) and '/' in str(g)])
        }

    def _analyze_director_stats(self) -> Dict[str,Any]:
        """分析导演统计"""
        director_data = []
        for directors in self.df['导演']:
            if pd.notna(directors) and str(directors) != '未知':
                # 简单的导演名字分割（根据逗号或顿号）
                director_list = re.split(r'[,，、]', str(directors))
                director_list = [d.strip() for d in director_list]
                director_data.extend(director_list)
        if director_data:
            director_series = pd.Series(director_data)
            director_counts = director_series.value_counts()
            return {
                'top_directors': director_counts.head(10).to_dict(),
                'total_directors': len(director_counts),
                'most_productive_director': director_counts.index[0],
                'director_movies_count': director_counts.iloc[0]
            }
        else:
            return {}
    def _analyze_actor_stats(self) -> Dict[str,Any]:
        """分析演员统计"""
        actor_data = []
        for actors in self.df['演员']:
            if pd.notna(actors) and str(actors) != '未知':
                # 简单的演员名字分割
                actor_list = re.split(r'[/／]', str(actors))
                actor_list = [a.strip() for a in actor_list if a.strip()]
                actor_data.extend(actor_list)
        if actor_data:
            actor_series = pd.Series(actor_data)
            actor_counts = actor_series.value_counts()
            return {
                'top_actors': actor_counts.head(15).to_dict(),
                'total_actors': len(actor_counts),
                'most_frequent_actor': actor_counts.index[0],
                'actor_movies_count': actor_counts.iloc[0]
            }
        else:
            return {}

    def create_rating_distribution_plot(self):
        """创建评分分布图"""
        if self.df is None or '评分' not in self.df.columns:
            return
        # 创建1行2列的子图网格
        # figsize 画布大小，宽15英寸，高6英寸
        # subplots() 返回两个值，fig表示整个画布，ax表示子图
        # (ax1,ax2) 两个子图对象的元组，分别表示左子图和右子图
        fig, (ax1, ax2) = plt.subplots(1,2, figsize=(15,6))
        # 直方图
        ratings = self.df['评分'].dropna()
        # 在左边图表上，用主色调画一个，包含20个柱子的半透明直方图，并加上白色边框让图表更好看
        # hist() -- 直方图绘制函数
        # bins=20  20个柱子
        # color=self.colors['primary'] 柱子的填充颜色
        # edgecolor='white'  柱子边框颜色为白色
        ax1.hist(ratings, bins=20,alpha=0.7,color=self.colors['primary'],edgecolor='white')
        # 在左边图表下方，写上‘评分’两个字，用黑体显示，且字号由配置字典统一管理
        # 将 评分 显示在X轴下方
        # fontproperties='SimHei' 指定字体为黑体
        # （Matplotlib默认不支持中文字体，直接写中文，图表上会显示成方框（乱码），所以需要指定字体）
        # fontsize 设置字体大小
        ax1.set_xlabel('评分',fontproperties='SimHei',fontsize=self.font_props['label']['fontsize'])
        #  在左边图表左侧，写上‘电影数量’四个字，用黑体显示，且字号由配置字典统一管理
        ax1.set_ylabel('电影数量',fontproperties='SimHei',fontsize=self.font_props['label']['fontsize'])
        ax1.set_title('豆瓣Top250评分分布',fontproperties='SimHei',fontsize=14,fontweight='bold')
        # 把左边图表上X轴和Y轴的数字（刻度标签）统一缩小/放大到10号字，让图表排版更美观
        # tick_params() 用于设置刻度线和刻度标签（是一个批量设置方法）
        ax1.tick_params(labelsize=10)
        # 在左边图表背景上，铺一层透明度为0.3的网格线，方便更直观地读取柱子的数值高度
        # grid() 控制网格线显示（True）/隐藏（False）
        ax1.grid(True,alpha=0.3)
        # 在右边图表上，画一个横向箱线图，用强调色填充箱体并加上透明度，方便和左边直方图，在同一个评分维度下进行对比
        # boxplot() -- 绘制一个水平方向的箱线图
        # vert=False 水平方向箱线图（横向）
        # patch_artist=True 启用箱体填充色
        # facecolor 设置箱体的填充颜色
        box = ax2.boxplot(ratings, vert=False,patch_artist=True,
                          boxprops=dict(facecolor=self.colors['accent'],alpha=0.7))
        ax2.set_xlabel('评分',fontproperties='SimHei',fontsize=self.font_props['label']['fontsize'])
        ax2.set_title('评分箱线图',fontproperties='SimHei',fontsize=14,fontweight='bold')
        # 把右边图表上X轴和Y轴的数字（刻度标签）统一缩小/放大到10号字，让图表排版更美观
        ax2.tick_params(labelsize=10)
        # 在右边图表背景上，铺一层透明度为0.3的网格线
        ax2.grid(True,alpha=0.3)
        # 自动调整整个画布的子图布局，防止各种标签和标题互相重叠
        plt.tight_layout()
        # 把这张排版好的图，以300高清分辨率、干净白底，裁剪掉多余白边后，保存到指定结果文件夹中
        # savefig() -- 将当前画布导出为图片文件
        # 文件夹路径 / 文件名
        # bbox_inches='tight' 自动裁剪图片的空白边缘
        # facecolor='white' 设置图片背景颜色为白色
        plt.savefig(self.results_dir / 'rating_distribution.png', dpi=300, bbox_inches='tight',
                    facecolor='white', edgecolor='white')
        plt.show()

    def create_year_trend_plot(self):
        """创建年份趋势图"""
        if self.df is None or '上映年份' not in self.df.columns:
            return
        # 提取年份数据
        df_year = self.df.copy()
        # 把‘上映年份’这列变成纯数字格式，遇到无法转换的乱码或文字，直接标记为缺失值（NaN），保证程序不报错
        df_year['上映年份'] = pd.to_numeric(df_year['上映年份'],errors='coerce')
        # 把没有有效上映年份的电影记录全部剔除掉，留下来的电影都是完整的
        df_year = df_year.dropna(subset=['上映年份'])
        if len(df_year) == 0:
            return
        # 按“上映年份”对数据分组，并对每年的评分和评价人数，进行多维度统计聚合，将结果保留两位小数
        # agg() -- 对不同列，用不同的统计规则
        year_stats = df_year.groupby('上映年份').agg({
            # 这列同时计算两个指标（电影平均评分，该年共有多少部电影）
            '评分': ['mean', 'count'],
            '评价人数': 'mean'
        }).round(2)  # 结果保留两位小数
        year_stats.columns = ['平均评分', '电影数量', '平均评价人数']
        # reset_index() 为什么需要
        # 因为分组统计后，年份变成了索引，而不是普通列（没有上映年份的列），需要把它变回来
        # reset_index() -- 把“索引”重新变回普通的“数据列”
        year_stats = year_stats.reset_index()
        # 准备一张宽14、高10的大画布，在里面上下切分出两个区域（2行1列），
        # 分别命名为ax1（上）和 ax2（下），为后面绘制双图做准备”
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 10))

        # 在子图（ax1）中绘制一个柱状图，展示每年上映的电影数量
        # bar() -- 绘制垂直柱状图
        # color -- 设置柱子的填充颜色
        ax1.bar(year_stats['上映年份'],year_stats['电影数量'],
                color=self.colors['primary'],alpha=0.7)
        # 为子图（ax1）设置X轴的标签文字（横坐标名称），并自定义它的字体和大小
        ax1.set_xlabel('上映年份', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
        ax1.set_ylabel('电影数量', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
        ax1.set_title('Top250电影上映年份分布', fontproperties='SimHei', fontsize=14, fontweight='bold')
        # 把子图上X轴和Y轴的数字（刻度标签）统一缩小/放大到10号字，让图表排版更美观
        ax1.tick_params(labelsize=10)
        # 在图表背景上，铺一层透明度为0.3的网格线，方便更直观地读取柱子的数值高度
        ax1.grid(True, alpha=0.3)
        # 为子图（ax2）创建一个共享X轴的“双Y轴”图表
        # （处理多维度数据对比）
        ax2_twin = ax2.twinx()
        # 在子图（ax2）中，绘制一条折线图，来展示每年电影的平均评分变化趋势
        # plot() -- 绘制折线图
        # X轴：'上映年份'，Y轴：'平均评分'
        # color -- 设置折线图的填充颜色
        # marker='o' -- 在折线的每一个数据点（即每个年份）上画一个圆点标记
        # linewidth=2 设置折线粗细为2磅
        # label -- 为这条折线设置一个图例标签
        line1 = ax2.plot(year_stats['上映年份'], year_stats['平均评分'],
                         color=self.colors['secondary'], marker='o', linewidth=2,
                         label='平均评分')
        # 为子图（ax2）设置X轴的标签文字，并自定义它的字体和大小
        ax2.set_xlabel('上映年份', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
        # 为子图（ax2）设置Y轴的标签文字，并自定义它的字体，大小和颜色
        ax2.set_ylabel('平均评分', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'],
                       color=self.colors['secondary'])
        # 对子图（ax2）左侧Y轴的“刻度数字”设置样式，让它们的颜色和大小，与折线图保持一致
        # （统一缩小/放大到10号字）
        ax2.tick_params(axis='y', labelcolor=self.colors['secondary'], labelsize=10)
        # 为子图（ax2）设置X轴刻度标签（即横坐标上的年份数字）的字体大小
        ax2.tick_params(axis='x', labelsize=10)

        # 在子图右侧Y轴上，绘制一条新折线图，展示“每年的平均评价人数”的变化趋势
        # marker='s' -- 在折线每个数据点上，画一个正方形（Square）标记
        line2 = ax2_twin.plot(year_stats['上映年份'], year_stats['平均评价人数'],
                              color=self.colors['accent'], marker='s', linewidth=2,
                              label='平均评价人数')
        ax2_twin.set_ylabel('平均评价人数', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'],
                            color=self.colors['accent'])
        # 对子图左侧Y轴的“刻度数字”设置样式，让它们的颜色和大小，与折线图保持一致
        # （统一缩小/放大到10号字）
        ax2_twin.tick_params(axis='y', labelcolor=self.colors['accent'], labelsize=10)
        # 将子图右侧的Y轴刻度比例设置为“对数刻度”（Logarithmic）
        ax2_twin.set_yscale('log')
        # 合并两条折线的图例（将两个列表拼接成一个列表）
        # lines中同时包含了"平均评分"和"平均评价人数"
        lines = line1 + line2
        # get_label() -- 获取通过label标签设置的标签名
        # l -- 每一条折线
        labels = [l.get_label() for l in lines]
        # 把左边轴和右边轴，两条折线打包在一起，提取它们中文名字，然后在图表的左上角，
        # 画一个图例框，让读者能同时看懂这两条折线分别代表什么
        # legend() -- 生成并显示图例
        # lines -- 图例框中对应的折线
        # labels -- 图例框中每条折现对应的标签名
        # loc='upper left' -- 图例框显示在图表的左上角
        # prop -- 定义图例框内文字的样式
        ax2.legend(lines, labels, loc='upper left', prop={'family': 'SimHei', 'size': 10})

        ax2.set_title('评分和评价人数随时间变化趋势', fontproperties='SimHei', fontsize=14, fontweight='bold')
        # 在图表背景上，铺一层透明度为0.3的网格线，方便更直观地读取折线图的数值高度
        ax2.grid(True, alpha=0.3)
        # 自动调整整个画布的子图布局，防止各种标签和标题互相重叠
        plt.tight_layout()
        plt.savefig(self.results_dir / 'year_trend_analysis.png', dpi=300, bbox_inches='tight',
                    facecolor='white', edgecolor='white')
        plt.show()

    def create_country_genre_analysis(self):
        """创建国家和类型分析图"""
        if self.df is None:
            return
        # ax1(左上)、ax2(右上)、ax3(左下)、ax4(右下) 四个子图
        fig,((ax1,ax2),(ax3,ax4)) = plt.subplots(2,2,figsize=(16,12))
        # 1. 国家地区分布
        if '国家地区' in self.df.columns:
            country_data = []
            for countries in self.df['国家地区']:
                if pd.notna(countries) and str(countries) != '未知':
                    country_list = [c.strip() for c in str(countries).split('/')]
                    country_data.extend(country_list)
            # 统计国家地区出现次数（频率最高），并取前10名，将其转为Series对象
            country_counts = pd.Series(country_data).value_counts().head(10)
            # 在左上角子图（ax1）中，绘制一个水平条形图，直观展示排名前10国家/地区的数据分布
            # barh() -- 水平条形图
            # range(len(country_counts)) -- 生成条形图在Y轴上的位置坐标
            # country_counts.values -- 每根条形的具体长度（x轴）
            # color -- 为这10根条形设置颜色
            ax1.barh(range(len(country_counts)),country_counts.values,
                color=sns.color_palette("husl",len(country_counts)))
            # 为水平条形图，设置Y轴上刻度的显示位置
            ax1.set_yticks(range(len(country_counts)))
            # 将水平条形图Y轴上默认的纯数字（0, 1, 2...），替换为真实的国家/地区中文名称
            ax1.set_yticklabels(country_counts.index,fontproperties='SimHei')
            ax1.set_xlabel('电影数量',fontproperties='SimHei',fontsize=self.font_props['label']['fontsize'])
            ax1.set_title('Top10国家/地区分布',fontproperties='SimHei',fontsize=12,fontweight='bold')
            # 对子图（ax1）设置大小
            # （统一缩小/放大到10号字）
            ax1.tick_params(labelsize=10)
            # 在图表背景上，铺一层透明度为0.3的网格线，方便更直观地读取水平条形图的数值高度
            ax1.grid(True,alpha=0.3)

        # 2. 电影类型分布
        if '电影类型' in self.df.columns:
            genre_data = []
            for genres in self.df['电影类型']:
                if pd.notna(genres) and str(genres) != '未知':
                    genre_list = [g.strip() for g in str(genres).split('/')]
                    genre_data.extend(genre_list)
            # 统计电影类型出现次数（频率最高），并取前10名，将其转为Series对象
            genre_counts = pd.Series(genre_data).value_counts().head(10)
            # 在右上角画个饼图，用柔和的Set3颜色区分各个电影类型，从正上方开始绘制，
            # 并在每个扇形块旁边标上名称，在内部标上保留一位小数的百分比，
            # 最后把扇形、名称、百分比的图形对象都保存下来，展示不同电影类型在总数据中所占的百分比
            # pie() -- 绘制饼图（默认返回三个重要的图形对象列表）
            #   wedges -- 饼图的扇形部分
            #   texts -- 饼图的标签部分
            #   autotexts -- 饼图内部的百分比文本
            # genre_counts.values -- 每个扇形块的大小（饼图数据）
            # genre_counts.index -- 在每个扇形块外侧，显示对应的电影类型名称（标签）
            # autopct -- 显示百分比（保留1位小数）
            # startangle=90 饼图绘制的起始角度
            # colors -- 为各个扇形块设置颜色
            wedges,texts,autotexts = ax2.pie(genre_counts.values,labels=genre_counts.index,
                autopct='%1.1f%%',startangle=90,
                colors=sns.color_palette("Set3",len(genre_counts)))
            # 遍历饼图外侧的中文标签
            for text in texts:
                # 设置黑体字体
                text.set_fontproperties('SimHei')
            for autotext in autotexts:
                # 百分比文本设置黑体字体
                autotext.set_fontproperties('SimHei')
            ax2.set_title('Top10电影类型分布',fontproperties='SimHei',fontsize=12,fontweight='bold')

        # 3. 类型与评分关系
        if '电影类型' in self.df.columns and '评分' in self.df.columns:
            genre_rating_data = []
            for idx, row in self.df.iterrows():
                if pd.notna(row['电影类型']) and str(row['电影类型']) != '未知':
                    genres = [g.strip() for g in str(row['电影类型']).split('/')]
                    for genre in genres:
                        # 将每部电影的类型和评分，添加到列表中
                        genre_rating_data.append({
                            '类型': genre,
                            '评分': row['评分']
                        })
            if genre_rating_data:
                # 将包含大量字典的列表，转换为DataFrame
                genre_rating_df = pd.DataFrame(genre_rating_data)
                # 从数据表中，筛选出电影数量最多的前8个类型，并提取它们名称
                top_genres = genre_rating_df['类型'].value_counts().head(8).index
                # 从原始数据表中，只保留属于那8个热门电影类型的数据
                # isin() -- 检查'类型'这列中的每一个值，是否存在于刚提取的top_genres列表中
                # genre_rating_df[ ... ] 布尔索引过滤 -- 只保留为True的行，False的行全部丢弃
                genre_rating_filtered = genre_rating_df[genre_rating_df['类型'].isin(top_genres)]
                # 在左下角子图（ax3）中，绘制一个箱线图，直观展示这8个，热门电影类型的评分分布情况
                # boxplot() -- 箱线图
                # data -- 绘制箱线图所用的数据源
                # x -- 显示电影类型
                # y -- 显示评分
                # ax -- 指定在哪个子图中绘制
                # palette -- 设置颜色调色板
                sns.boxplot(data=genre_rating_filtered,x='类型',y='评分',ax=ax3,
                    palette="Set2")
                # 将左下角箱线图X轴上，中文类型名称，调整为倾斜45度右对齐显示，并强制指定黑体字体
                ax3.set_xticklabels(ax3.get_xticklabels(), rotation=45, ha='right', fontproperties='SimHei')
                ax3.set_ylabel('评分', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
                ax3.set_title('主要类型评分分布', fontproperties='SimHei', fontsize=12, fontweight='bold')
                # 调整左下角箱线图（ax3）上，所有刻度标签（包括X轴和Y轴）的字体大小
                ax3.tick_params(labelsize=10)

        # 4. 合作制片分析
        if '国家地区' in self.df.columns:
            co_production = []
            for countries in self.df['国家地区']:
                if pd.notna(countries) and str(countries) != '未知':
                    country_count = len([c.strip() for c in str(countries).split('/')])
                    co_production.append(country_count)
            # 统计各个“合拍国家/地区”组合出现的次数，将结果按名称的字母/拼音顺序重新排序
            co_prod_counts = pd.Series(co_production).value_counts().sort_index()
            # 在右下角子图（ax4）中，绘制一个垂直条形图，展示不同国家联合制作的电影数量分布
            # bar() -- 绘制垂直条形图
            # co_prod_counts.index -- X轴，合作国家数量
            # co_prod_counts.values -- Y轴，电影数量
            # color -- 设置条形图颜色
            ax4.bar(co_prod_counts.index, co_prod_counts.values,
                color=self.colors['success'], alpha=0.7)
            ax4.set_xlabel('合作国家数量', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
            ax4.set_ylabel('电影数量', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
            ax4.set_title('国际合作制片情况', fontproperties='SimHei', fontsize=12, fontweight='bold')
            # 调整右下角箱线图（ax4）上，所有刻度标签（包括X轴和Y轴）的字体大小
            ax4.tick_params(labelsize=10)
            # 在图表背景上，铺一层透明度为0.3的网格线，更直观地读取水平条形图的数值高度
            ax4.grid(True, alpha=0.3)
        # 自动调整整个画布的子图布局，防止各种标签和标题互相重叠
        plt.tight_layout()
        # 将绘制好的4宫格图表，以高清PNG格式保存到本地指定文件夹中
        plt.savefig(self.results_dir / 'country_genre_analysis.png', dpi=300, bbox_inches='tight',
                   facecolor='white', edgecolor='white')
        plt.show()

    def create_director_actor_analysis(self):
        """创建导演演员分析图"""
        if self.df is None:
            return
        fig,((ax1,ax2),(ax3,ax4)) = plt.subplots(2,2,figsize=(16,12))

        # 1. 高产导演分析
        if '导演' in self.df.columns:
            # 调用私有方法，统计所有导演及其电影数量
            director_stats = self._analyze_director_stats()
            # 包含前10位高产导演及作品数
            if director_stats and 'top_directors' in director_stats:
                # 从'top_directors'字典中提取导演姓名列表，截取前8位
                top_directors = list(director_stats['top_directors'].keys())[:8]
                # 从'top_directors'字典中提取对应的电影数量列表，同样截取前8个
                movie_counts = list(director_stats['top_directors'].values())[:8]
                # 在左上角子图（ax1）中，绘制水平条形图展示Top8高产导演的电影数量
                # barh() -- 水平条形图，Y轴为导演，X轴为电影数量
                # color -- 使用seaborn的"Blues_r"反转蓝色调色板，按导演数量生成渐变
                ax1.barh(range(len(top_directors)), movie_counts,
                    color=sns.color_palette("Blues_r", len(top_directors)))
                # 将Y轴刻度位置设置为与导演数量对应的整数序列，确保每个条形都有刻度
                ax1.set_yticks(range(len(top_directors)))
                # 设置y轴标签，处理长名字
                y_labels = [d[:10] + '...' if len(d) > 10 else d for d in top_directors]
                # 给图表Y轴上的刻度标签，设置为指定的中文文本（y_labels），使用黑体字体来渲染
                ax1.set_yticklabels(y_labels, fontproperties='SimHei')
                ax1.set_xlabel('电影数量', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
                ax1.set_title('Top8高产导演', fontproperties='SimHei', fontsize=12, fontweight='bold')
                # 调整左上角箱线图（ax1）上，所有刻度标签（包括X轴和Y轴）的字体大小
                ax1.tick_params(labelsize=10)
                # 在图表背景上，铺一层透明度为0.3的网格线，更直观地读取水平条形图的数值高度
                ax1.grid(True, alpha=0.3)

        # 2. 频繁出演演员
        if '演员' in self.df.columns:
            # 调用私有方法，统计所有演员及其出演电影数量
            actor_stats = self._analyze_actor_stats()
            # 包含前10位高频演员及作品数
            if actor_stats and 'top_actors' in actor_stats:
                # 从'top_actors'字典中提取演员姓名列表，截取前10位
                top_actors = list(actor_stats['top_actors'].keys())[:10]
                # 从'top_actors'字典中提取对应的出演电影数量列表，同样截取前10个
                appearance_counts = list(actor_stats['top_actors'].values())[:10]
                # 在右上角子图（ax2）中，绘制垂直条形图展示Top10频繁出演演员的出演次数
                # bar() -- 垂直条形图，X轴为演员，Y轴为出演电影数量
                # color -- 使用seaborn的"Reds_r"反转红色调色板，按演员数量生成渐变色
                ax2.bar(range(len(top_actors)), appearance_counts,
                       color=sns.color_palette("Reds_r", len(top_actors)))
                # 将X轴刻度位置设置为与演员数量对应的整数序列，确保每个条形都有刻度
                ax2.set_xticks(range(len(top_actors)))
                # 设置x轴标签，处理长名字
                x_labels = [a[:8] + '...' if len(a) > 8 else a for a in top_actors]
                # 将截断后的演员名设置为X轴刻度标签，旋转45度右对齐，使用黑体字体
                ax2.set_xticklabels(x_labels, rotation=45, ha='right', fontproperties='SimHei')
                # 统一设置右上角子图（ax2）的Y轴标签、标题、刻度字号和背景网格
                ax2.set_ylabel('出演电影数量', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
                ax2.set_title('Top10频繁出演演员', fontproperties='SimHei', fontsize=12, fontweight='bold')
                # 调整右上角箱线图（ax2）上，所有刻度标签（包括X轴和Y轴）的字体大小
                ax2.tick_params(labelsize=10)
                # 在图表背景上，铺一层透明度为0.3的网格线，更直观地读取水平条形图的数值高度
                ax2.grid(True, alpha=0.3)

        # 3. 评分与评价人数关系
        if '评分' in self.df.columns and '评价人数' in self.df.columns:
            # 在左下角子图（ax3）中，绘制散点图，展示评分与评价人数的关系
            # x轴 -- 评价人数
            # y轴 -- 评分
            # color -- 设置散点颜色
            # s -- 设置每个散点大小为50
            ax3.scatter(self.df['评价人数'], self.df['评分'],
                alpha=0.6, color=self.colors['primary'], s=50)
            # 设置X轴的中文标签
            ax3.set_xlabel('评价人数', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
            # 设置Y轴的中文标签
            ax3.set_ylabel('评分', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
            # 设置图表标题
            ax3.set_title('评分 vs 评价人数', fontproperties='SimHei', fontsize=12, fontweight='bold')
            # 将X轴（评价人数）设置为对数刻度
            ax3.set_xscale('log')
            # 调整左下角箱线图（ax3）上，所有刻度标签（包括X轴和Y轴）的字体大小
            ax3.tick_params(labelsize=10)
            # 在图表背景上，铺一层透明度为0.3的网格线，更直观地读取水平条形图的数值高度
            ax3.grid(True, alpha=0.3)
            # 添加趋势线
            # len(self.df) > 1 检查数据集里是否至少有2条数据（不然散点图没有任何意义）
            # self.df['评价人数'].min() > 0：检查“评价人数”的最小值是否大于0
            if len(self.df) > 1 and self.df['评价人数'].min() > 0:
                # 将“评价人数”，这一列数据，整体转换为对数值，并赋值
                x_data = np.log(self.df['评价人数'])
                # 将“评分”列数据提取出来，并赋值
                y_data = self.df['评分']
                # isfinite() -- 移除NaN（非数字）和inf（无穷大）值
                mask = np.isfinite(x_data) & np.isfinite(y_data)
                # 检查清洗后，剩下的有效数据点，是否大于1个
                if mask.sum() > 1:
                    # 线性拟合
                    # 传入清洗后的x_data（评价人数的对数）和y_data（评分）
                    # 1 代表拟合的阶数为1，即一次多项式（直线）
                    z = np.polyfit(x_data[mask], y_data[mask], 1)
                    # 将拟合得到的系数z，封装成一个可调用的，多项式函数对象p
                    p = np.poly1d(z)
                    # 在对数尺度上生成 100 个均匀分布的点
                    # 起点是数据的最小值，终点是数据的最大值
                    x_line = np.logspace(np.log10(self.df['评价人数'].min()),
                        np.log10(self.df['评价人数'].max()), 100)
                    # 绘制趋势线
                    # plot(x,y)
                    # 使用字典中的警告色，线宽设为2
                    ax3.plot(x_line, p(np.log(x_line)), color=self.colors['warning'], linewidth=2)

        # 4. 电影时长与评分关系（如果有数据的话）
        # 自动调整整个画布的子图布局，防止各种标签和标题互相重叠
        plt.tight_layout()
        # 将绘制好的4宫格图表，以高清PNG格式保存到本地指定文件夹中
        plt.savefig(self.results_dir / 'director_actor_analysis.png',dpi=300,
            bbox_inches='tight',facecolor='white',edgecolor='white')
        plt.show()

    def create_comprehensive_report(self):
        """创建综合分析报告"""
        if self.df is None:
            print("没有数据可供分析")
            return
        print("=" * 60)
        print("豆瓣电影Top250数据分析报告")
        print("=" * 60)
        # 基础统计
        stats = self.basic_statistics()
        print(f"\n📊 基础统计信息:")
        print(f"   电影总数: {stats['total_movies']} 部")

        if stats['time_range']:
            print(f"   时间跨度: {stats['time_range']['min_year']} - {stats['time_range']['max_year']} "
                  f"({stats['time_range']['year_span']} 年)")
        if stats['rating_stats']:
            print(f"   平均评分: {stats['rating_stats']['mean_rating']} 分")
            print(f"   最高评分: {stats['rating_stats']['max_rating']} 分")
            print(f"   评分标准差: {stats['rating_stats']['std_rating']} 分")
        if stats['vote_stats']:
            print(f"   总评价人数: {stats['vote_stats']['total_votes']:,} 人")
            print(f"   平均评价人数: {stats['vote_stats']['mean_votes']:,} 人")
        # 国家地区分析
        if stats['country_distribution']:
            print(f"\n🌍 国家地区分析:")
            print(f"  涉及国家/地区: {stats['country_distribution']['total_countries']} 个")
            print(f"  合作制片电影: {stats['country_distribution']['co_production_movies']} 部")
            print("   主要国家分布:")
            # 从列表中获取排名前5的国家及其数量
            for country,count in list(stats['country_distribution']['top_countries'].items())[:5]:
                print(f"     {country}: {count} 部")
        # 类型分析
        if stats['genre_distribution']:
            print(f"\n🎬 电影类型分析:")
            print(f"   涉及类型: {stats['genre_distribution']['total_genres']} 种")
            print(f"   混合类型电影: {stats['genre_distribution']['mixed_genres_movies']} 部")
            print("   主要类型分布:")
            for genre,count in list(stats['genre_distribution']['top_genres'].items())[:5]:
                print(f"     {genre}: {count} 部")
        # 导演演员分析
        if stats['director_stats']:
            print(f"\n🎥 导演分析:")
            print(f"   涉及导演: {stats['director_stats']['total_directors']} 位")
            if 'most_productive_director' in stats['director_stats']:
                print(f"   最高产导演: {stats['director_stats']['most_productive_director']} "
                      f"({stats['director_stats']['director_movies_count']} 部)")
        if stats['actor_stats']:
            print(f"\n🎭 演员分析:")
            print(f"   涉及演员: {stats['actor_stats']['total_actors']} 位")
            if 'most_frequent_actor' in stats['actor_stats']:
                print(f"   最频繁出演: {stats['actor_stats']['most_frequent_actor']} "
                      f"({stats['actor_stats']['actor_movies_count']} 部)")
        print(f"\n💾 分析结果已保存到: {self.results_dir}")
        print("=" * 60)

    def export_analysis_results(self):
        """导出分析结果到Excel"""
        if self.df is None:
            return
        # 创建详细的分析数据
        # 使用openpyxl引擎创建Excel写入器，用with语句确保写入完成后自动关闭文件
        with pd.ExcelWriter(self.results_dir / 'detailed_analysis.xlsx',engine='openpyxl',mode='w') as writer:
            # 将清洗后的完整原始数据，写入"原始数据"工作表，不写入行索引
            self.df.to_excel(writer, sheet_name='原始数据', index=False)
            # 按年份统计
            if '上映年份' in self.df.columns:
                # 按"上映年份"分组，聚合计算每年的电影数量、评分统计（均值/最高/最低）和评价人数统计
                year_stats = self.df.groupby('上映年份').agg({
                    '电影名': 'count',
                    '评分': ['mean', 'max', 'min'],
                    '评价人数': ['mean', 'sum']
                }).round(2)
                # 将多级列名重命名为易读中文名
                year_stats.columns = ['电影数量','平均评分','最高评分','最低评分',
                    '平均评价人数','总评价人数']
                # 写入Excel
                year_stats.to_excel(writer,sheet_name='年份统计')

            # 类型统计
            if '类型统计' in self.df.columns:
                # 按电影类型分组统计电影数量、评分和评价人数
                genre_stats = self._get_detailed_genre_stats()
                # 仅在类型统计数据非空时写入Excel，避免生成空白工作表
                if not genre_stats.empty:
                    genre_stats.to_excel(writer, sheet_name='类型统计')
                # 国家统计
            if '国家地区' in self.df.columns:
                # 按国家/地区分组统计电影数量、评分和评价人数
                country_stats = self._get_detailed_country_stats()
                # 仅在国家统计数据非空时写入Excel，避免生成空白工作表
                if not country_stats.empty:
                    country_stats.to_excel(writer, sheet_name='国家统计')
            print(f"详细分析结果已导出到: {self.results_dir / 'detailed_analysis.xlsx'}")

    def _get_detailed_genre_stats(self) -> pd.DataFrame:
        """获取详细的类型统计"""
        genre_data = []
        for idx, row in self.df.iterrows():
            if pd.notna(row['电影类型']) and str(row['电影类型']) != '未知':
                genres = [g.strip() for g in str(row['电影类型']).split('/')]
                for genre in genres:
                    genre_data.append({
                        '类型': genre,
                        '电影名': row['电影名'],
                        '评分': row['评分'],
                        '评价人数': row['评价人数']
                    })
        # 如果收集到了有效的类型数据，则进行分组聚合统计
        if genre_data:
            # 将字典列表转换为DataFrame，每行代表一部电影的某个类型信息
            genre_df = pd.DataFrame(genre_data)
            # 按"类型"分组，聚合计算每个类型的电影数量、评分统计（均值/最高/最低）和平均评价人数
            # round(2) -- 将所有数值结果四舍五入保留两位小数
            stats = genre_df.groupby('类型').agg({
                '电影名': 'count',
                '评分': ['mean','max','min'],
                '评价人数': 'mean'
            }).round(2)
            # 将多级列索引重命名为易读中文名
            stats.columns = ['电影数量','平均评分','最高评分','最低评分','平均评价人数']
            # 按电影数量降序排列后返回，使热门类型排在前面
            return stats.sort_values('电影数量',ascending=False)
        else:
            # 若无有效类型数据，返回空DataFrame
            return pd.DataFrame()

    def _get_detailed_country_stats(self) -> pd.DataFrame:
        """获取详细的国家统计"""
        country_data = []
        for idx, row in self.df.iterrows():
            if pd.notna(row['国家地区']) and str(row['国家地区']) != '未知':
                countries = [c.strip() for c in str(row['国家地区']).split('/')]
                for country in countries:
                    country_data.append({
                        '国家地区': country,
                        '电影名': row['电影名'],
                        '评分': row['评分'],
                        '评价人数': row['评价人数']
                    })

        if country_data:
            country_df = pd.DataFrame(country_data)
            stats = country_df.groupby('国家地区').agg({
                '电影名': 'count',
                '评分': ['mean','max','min'],
                '评价人数': 'mean'
            }).round(2)
            # 将多级列索引重命名为易读中文名
            stats.columns = ['电影数量','平均评分','最高评分','最低评分','平均评价人数']
            # 按电影数量降序排列后返回，使热门电影国家排在前面
            return stats.sort_values('电影数量',ascending=False)
        else:
            # 若无有效类型数据，返回空DataFrame
            return pd.DataFrame()

    def run_complete_analysis(self):
        """运行完整的数据分析流程"""
        print("开始豆瓣电影Top250完整数据分析...")
        # 1. 加载数据
        if not self.load_data():
            return
        # 2. 基础统计分析
        print("正在进行基础统计分析...")
        stats = self.basic_statistics()
        # 3. 创建可视化图表
        print("正在生成可视化图表...")
        # 评分分布分析
        self.create_rating_distribution_plot()
        print("✅ 评分分布图已生成")
        # 年份趋势分析
        self.create_year_trend_plot()
        print("✅ 年份趋势图已生成")
        # 国家类型分析
        self.create_country_genre_analysis()
        print("✅ 国家类型分析图已生成")
        # 导演演员分析
        self.create_director_actor_analysis()
        print("✅ 导演演员分析图已生成")
        # 4. 生成分析报告
        print("正在生成分析报告...")
        self.create_comprehensive_report()
        # 5. 导出详细结果
        print("正在导出分析结果...")
        self.export_analysis_results()
        print("\n🎉 数据分析完成！")
        print(f"所有结果已保存到: {self.results_dir}")
        return stats

    def create_top_movies_analysis(self):
        """创建Top电影分析"""
        if self.df is None:
            return
        # 按评分降序取前10部电影
        top_rated = self.df.nlargest(10,'评分')
        # 按评价人数降序取前10部电影
        most_popular = self.df.nlargest(10,'评价人数')
        # 创建2行1列的垂直子图布局，画布尺寸为14x12英寸
        fig,(ax1,ax2) = plt.subplots(2,1,figsize=(14,12))
        # 最高评分电影
        # 在上方子图（ax1）中，绘制水平条形图展示Top10最高评分电影的评分
        # barh() -- 水平条形图，Y轴为电影，X轴为评分
        # color -- 用seaborn的"viridis"调色板，按电影数量生成渐变色
        bars1 = ax1.barh(range(len(top_rated)),top_rated['评分'],
            color=sns.color_palette("viridis",len(top_rated)))
        # 将Y轴刻度位置，设置为与电影数量对应的整数序列，确保每个条形都有刻度
        ax1.set_yticks(range(len(top_rated)))
        # 处理电影名称长度
        y_labels = []
        for name in top_rated['电影名']:
            if len(name) > 20:
                y_labels.append(name[:18] + '...')
            else:
                y_labels.append(name)
        # 将Y轴刻度标签，替换为变量y_labels提供的文本，指定使用黑体字体显示这些标签
        ax1.set_yticklabels(y_labels,fontproperties='SimHei')
        # 将X轴标签文本，设置为“评分”，使用黑体字体，通过fontsize参数动态指定字体大小
        ax1.set_xlabel('评分',fontproperties='SimHei',fontsize=self.font_props['label']['fontsize'])
        # 将图表标题，设置为“Top10 最高评分电影”，使用黑体字体，通过fontsize参数动态指定字体大小，并加粗
        ax1.set_title('Top10 最高评分电影',fontproperties='SimHei',fontsize=14,fontweight='bold')
        # 将X轴和Y轴上的刻度数字，统一设置为10号字体
        ax1.tick_params(labelsize=10)
        # 在图表中添加半透明网格线
        ax1.grid(True,alpha=0.3)

        # 在条形图上添加评分值
        # 遍历每个条形和对应评分，在条形右端外侧标注具体评分数值
        # get_width() -- 获取条形宽度（即评分值），+0.05为留出间距防止文字与条形重叠
        # get_y() + get_height()/2 -- 计算条形垂直中心位置，使文字纵向居中对齐
        # ha='left' -- 文本左边缘将与指定X坐标点对齐（水平对齐方式为左对齐）
        # va='center' 文本垂直中心线，将与指定Y坐标点对齐
        for i,(bar, rating) in enumerate(zip(bars1,top_rated['评分'])):
            ax1.text(bar.get_width() + 0.05, bar.get_y() + bar.get_height()/2,
                f'{rating}',ha='left',va='center')
        # 最受欢迎电影（按评价人数）
        # 在下方子图（ax2）中，绘制水平条形图展示Top10最受欢迎电影的评价人数
        # barh() -- 水平条形图，Y轴为电影，X轴为评价人数
        # color -- 用seaborn的"plasma"调色板，按电影数量生成渐变色
        bars2 = ax2.barh(range(len(most_popular)),most_popular['评价人数'],
            color=sns.color_palette("plasma",len(most_popular)))
        # 将Y轴刻度位置，设置为与电影数量，对应的整数序列，确保每个条形都有刻度
        ax2.set_yticks(range(len(most_popular)))
        # 处理电影名称长度
        y_labels2 = []
        for name in most_popular['电影名']:
            if len(name) > 20:
                y_labels2.append(name[:18] + '...')
            else:
                y_labels2.append(name)
        # 将Y轴刻度标签，替换为变量y_labels2提供的文本，指定使用黑体字体显示这些标签
        ax2.set_yticklabels(y_labels2,fontproperties='SimHei')
        # 将X轴标签文本，设置为“评价人数”，使用黑体字体，通过fontsize参数动态指定字体大小
        ax2.set_xlabel('评价人数',fontproperties='SimHei',fontsize=self.font_props['label']['fontsize'])
        ax2.set_title('Top10 最受欢迎电影（按评价人数）',fontproperties='SimHei',fontsize=14,fontweight='bold')
        ax2.tick_params(labelsize=10)  # 将X轴和Y轴上的刻度数字，统一设置为10号字体
        ax2.grid(True,alpha=0.3)  # 在图表中添加半透明网格线
        # 设置X轴为对数刻度
        ax2.set_xscale('log')
        # 自动调整整个画布的子图布局，防止各种标签和标题互相重叠
        plt.tight_layout()
        plt.savefig(self.results_dir / 'top_movies_analysis.png',dpi=300,
            bbox_inches='tight',facecolor='white',edgecolor='white')
        plt.show()
        return top_rated,most_popular

    def create_decade_analysis(self):
        """创建年代分析"""
        if self.df is None or '上映年份' not in self.df.columns:
            return
        # 提取年份并计算年代
        df_decade = self.df.copy()
        # 将DataFrame中的'上映年份'列，强制转换为数值类型
        # errors='coerce' -- 将无法转换的值，设置为NaN
        df_decade['上映年份'] = pd.to_numeric(df_decade['上映年份'],errors='coerce')
        # 把刚刚转换出来的NaN行删掉
        df_decade = df_decade.dropna(subset=['上映年份'])
        # // 将上映年份除以10，并向下取整（丢弃余数）
        # 例如1995 // 10结果是199
        # *10 还原为标准的年代格式， 例如199 * 10 的结果是1990
        df_decade['年代'] = (df_decade['上映年份'] // 10) * 10
        # 按年代分组聚合统计
        decade_stats = df_decade.groupby('年代').agg({
            '电影名': 'count',
            '评分': 'mean',
            '评价人数': 'mean'
        }).round(2)
        # 将聚合后，默认的英文/原始列名，替换为直观的中文名
        decade_stats.columns = ['电影数量', '平均评分', '平均评价人数']
        # groupby操作后，列默认会变成DataFrame索引
        # reset_index() 将它重新变回普通数据列
        decade_stats = decade_stats.reset_index()
        # 创建1行2列水平子图布局，画布尺寸为15x6英寸
        fig,(ax1,ax2) = plt.subplots(1,2,figsize=(15,6))

        # 年代电影数量分布
        # 在左侧子图（ax1）中，绘制垂直条形图展示各年代的电影数量分布
        # bar() -- 垂直条形图，X轴为年代，Y轴为电影数量
        # width=8 -- 设置条形宽度为8个单位，使相邻年代的条形紧密排列
        # alpha=0.7 -- 设置条形透明度为0.7，增加视觉层次感
        ax1.bar(decade_stats['年代'],decade_stats['电影数量'],
            width=8,alpha=0.7,color=self.colors['primary'])
        # 统一设置左侧子图（ax1）的X轴标签、Y轴标签、标题、刻度字号和背景网格
        ax1.set_xlabel('年代',fontproperties='SimHei',fontsize=self.font_props['label']['fontsize'])
        ax1.set_ylabel('电影数量',fontproperties='SimHei',fontsize=self.font_props['label']['fontsize'])
        ax1.set_title('各年代电影数量分布',fontproperties='SimHei',fontsize=14,fontweight='bold')
        ax1.tick_params(labelsize=10)
        ax1.grid(True,alpha=0.3)
        # 年代评分趋势
        # 在右侧子图（ax2）中，绘制折线图展示各年代平均评分的变化趋势
        # plot() -- 折线图，marker='o'在每个数据点绘制圆形标记，linewidth=2加粗折线
        ax2.plot(decade_stats['年代'],decade_stats['平均评分'],
            marker='o',linewidth=2,color=self.colors['secondary'],label='平均评分')
        # 统一设置右侧子图（ax2）的X轴标签、Y轴标签、标题、刻度字号和背景网格
        ax2.set_xlabel('年代', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
        ax2.set_ylabel('平均评分', fontproperties='SimHei', fontsize=self.font_props['label']['fontsize'])
        ax2.set_title('各年代平均评分趋势', fontproperties='SimHei', fontsize=14, fontweight='bold')
        ax2.tick_params(labelsize=10)
        ax2.grid(True,alpha=0.3)
        # 在右侧子图右上角显示图例，用黑体字体标注"平均评分"折线
        ax2.legend(prop={'family': 'SimHei'})
        # 添加评分值标注
        # 遍历每个年代及其平均评分，在折线图的数据点上方标注具体评分数值
        # textcoords="offset points" -- 以数据点为基准，使用像素偏移量定位文字
        # xytext=(0,10) -- 文字在数据点正上方偏移10个像素，避免遮挡数据点
        # ha='center' -- 文字水平居中对齐数据点
        for i, (year, rating) in enumerate(zip(decade_stats['年代'],decade_stats['平均评分'])):
            # annotate -- 添加标注内容
            # f'{rating}'：要显示的文字内容
            # (year, rating)：标注指向的数据点坐标（x轴是年份，y轴是评分）
            ax2.annotate(f'{rating}', (year, rating),
                textcoords="offset points",xytext=(0,10),ha='center')
        # 自动调整整个画布的子图布局，防止标签和标题互相重叠
        plt.tight_layout()
        # 将绘制好的年代分析图表，以高清PNG格式保存到本地指定文件夹
        # bbox_inches='tight' -- 裁剪图表边缘多余空白
        plt.savefig(self.results_dir / 'decade_analysis.png',dpi=300,bbox_inches='tight',
            facecolor='white',edgecolor='white')
        plt.show()
        return decade_stats

    def create_correlation_analysis(self):
        """创建相关性分析"""
        if self.df is None:
            return
        # 选择数值列进行相关性分析
        numeric_columns = ['评分','评价人数']
        if '上映年份' in self.df.columns:
            df_corr = self.df.copy()
            # 将DataFrame中的'上映年份'列，强制转换为数值类型
            # errors='coerce' -- 将无法转换的值，设置为NaN
            df_corr['上映年份'] = pd.to_numeric(df_corr['上映年份'],errors='coerce')
            numeric_columns.append('上映年份')
        # 提取出一个只包含数值型数据、且没有缺失值（NaN）的数据集
        df_numeric = df_corr[numeric_columns].dropna()
        if len(df_numeric) < 2:
            print("数据不足，无法进行相关性分析")
            return None

        # 计算相关系数矩阵
        # corr() -- 计算所有数值列之间的皮尔逊相关系数，返回对称矩阵
        corr_matrix = df_numeric.corr()
        # 创建8x6英寸的单画布，用于展示相关性热力图
        fig,ax = plt.subplots(figsize=(8,6))
        # 绘制热力图
        # imshow() -- 将相关系数矩阵渲染为热力图
        # cmap='coolwarm' -- 使用冷色（负相关）到暖色（正相关）的配色方案
        # vmin=-1, vmax=1 -- 固定色标范围为[-1, 1]，确保颜色与相关系数一一对应
        im = ax.imshow(corr_matrix.values,cmap='coolwarm',aspect='auto',
            vmin=-1,vmax=1)
        # 设置坐标轴
        # 将X轴和Y轴刻度位置，设置为与矩阵行列数对应的整数序列
        ax.set_xticks(range(len(corr_matrix.columns)))
        ax.set_yticks(range(len(corr_matrix.columns)))
        # 将刻度标签设置为中文列名，使用黑体字体确保中文正常显示
        ax.set_xticklabels(corr_matrix.columns,fontproperties='SimHei')
        ax.set_yticklabels(corr_matrix.columns,fontproperties='SimHei')
        # 添加相关系数值
        # corr_matrix.columns — 获取相关系数矩阵的所有列名（如 ['评分', '评价人数', '上映年份']）
        # len(corr_matrix.columns) — 获取列数（例如3列则返回3）
        for i in range(len(corr_matrix.columns)):
            # 再遍历，形成行列的双重循环，覆盖矩阵中所有格子
            for j in range(len(corr_matrix.columns)):
                # j -  x坐标，决定文字水平方向位置
                # i - y坐标，决定文字垂直方向位置
                # iloc[i,j]取出矩阵第i行第j列相关系数值，格式化为保留两位小数的字符串
                # ha="center" 水平对齐方式为居中
                # va="center" 垂直对齐方式为居中
                # color="w" 文字颜色为白色（在热力图上，深色背景配白色文字更清晰）
                text = ax.text(j,i,f'{corr_matrix.iloc[i,j]:.2f}',
                    ha="center",va="center",color="w",fontweight='bold')
        ax.set_title('变量相关性分析热力图',fontproperties='SimHei',fontsize=14,fontweight='bold')
        # 为热力图添加颜色条，展示颜色与数值间对应关系
        # im — 指定颜色条关联的图像对象
        # ax=ax — 指定颜色条绘制在哪个子图上
        plt.colorbar(im,ax=ax)
        # 自动调整整个画布的子图布局，防止标签和标题互相重叠
        plt.tight_layout()
        # 将绘制好的评分和评价人数图，以高清PNG格式保存到本地指定文件夹
        # bbox_inches='tight' -- 裁剪图表边缘多余空白
        plt.savefig(self.results_dir / 'correlation_analysis.png',dpi=300,
            bbox_inches='tight',facecolor='white',edgecolor='white')
        plt.show()
        return corr_matrix

    def run_all_analysis(self):
        """运行所有分析"""
        print("=" * 60)
        print("开始运行豆瓣电影Top250全面分析")
        print("=" * 60)
        # 加载数据
        if not self.load_data():
            print("数据加载失败，请检查数据文件")
            return
        # 运行所有分析函数
        print("\n1. 生成基础统计报告...")
        self.create_comprehensive_report()

        print("\n2. 生成评分分布图...")
        self.create_rating_distribution_plot()

        print("\n3. 生成年份趋势图...")
        self.create_year_trend_plot()

        print("\n4. 生成国家类型分析图...")
        self.create_country_genre_analysis()

        print("\n5. 生成导演演员分析图...")
        self.create_director_actor_analysis()

        print("\n6. 生成Top电影分析...")
        self.create_top_movies_analysis()

        print("\n7. 生成年代分析...")
        self.create_decade_analysis()

        print("\n8. 生成相关性分析...")
        self.create_correlation_analysis()

        print("\n9. 导出详细结果...")
        self.export_analysis_results()

        print("\n" + "=" * 60)
        print("🎉 所有分析完成！")
        print(f"📁 结果保存在: {self.results_dir}")
        print("=" * 60)

# 独立的字体修复函数
def fix_chinese_font():
    """单独运行此函数来检查和修复字体问题"""
    import platform

    system = platform.system()
    print(f"操作系统: {system}")
    # 打印当前字体设置
    print(f"当前字体: {plt.rcParams['font.sans-serif']}")
    print(f"Unicode设置: {plt.rcParams['axes.unicode_minus']}")
    # 创建一个图表画布（fig）和一个子图（ax）
    fig,ax = plt.subplots(figsize=(8,4))
    # 在坐标系中添加一段自定义文本
    # 0.5,0.5：文本放置的X轴和Y轴坐标位置
    # '中文测试: 豆瓣电影分析'：在坐标中要显示的文本内容
    # ha='center'：设置文本水平对齐方式为居中
    # va='center'：设置文本垂直对齐方式为居中
    # 设置文本字体为黑体
    ax.text(0.5,0.5,'中文测试: 豆瓣电影分析',
        fontsize=20,ha='center',va='center',fontproperties='SimHei')
    ax.set_title('中文标题测试',fontproperties='SimHei')
    ax.set_xlabel('X轴中文',fontproperties='SimHei')
    ax.set_ylabel('Y轴中文',fontproperties='SimHei')
    # 去掉x坐标轴刻度
    ax.set_xticks([])
    # 去掉y坐标轴刻度
    ax.set_yticks([])
    # 自动调整整个画布的子图布局，防止标签和标题互相重叠
    plt.tight_layout()
    plt.savefig('chinese_test.png',dpi=300,bbox_inches='tight')
    plt.show()
    print("✅ 测试图表已保存为 'chinese_test.png'")

# 主程序入口
def main():
    """主函数"""
    import sys

    analyzer = DouBanAnalyzer()
    # 判断用户是否在命令行中传入了至少一个参数
    # 如：python analyzer.py --quick则
    # sys.argv=['analyzer.py','--quick']，长度为2
    if len(sys.argv) > 1:
        # 判断用户传入的参数是否为--test-font（环境调试）
        # （生成一张测试图，验证中文能否正常显示（不出现乱码/方块））
        if sys.argv[1] == '--test-font':
            # 生成一张包含中文的测试图表，验证中文字体是否能正常显示
            fix_chinese_font()
        # 判断用户传入的参数是否为--quick（快速预览）
        # （只加载数据并打印文字报告，不生成任何图表）
        elif sys.argv[1] == '--quick':
            # 加载清洗后的数据文件
            analyzer.load_data()
            # 在控制台打印一份纯文字的综合统计报告
            analyzer.create_comprehensive_report()
        # 判断用户传入的参数是否为--full（正式分析）
        # （触发完整分析模式（生成8种图表+报告+导出Excel））
        elif sys.argv[1] == '--full':
            # 按顺序执行全部分析流程：加载数据→生成8种可视化图表→打印报告→导出Excel
            analyzer.run_all_analysis()
        else:
            print("使用方法:")
            print("  python analyzer.py                    # 完整分析")
            print("  python analyzer.py --test-font        # 测试字体")
            print("  python analyzer.py --quick            # 快速分析")
            print("  python analyzer.py --full             # 完整分析")
            print("  python analyzer.py --interactive      # 交互模式")
    else:
        # 默认运行完整分析
        analyzer.run_all_analysis()

if __name__ == "__main__":
    # 首先设置字体
    setup_chinese_font()
    # 运行主程序
    main()

'''
如何启动cleaner.py以及analyzer.py这两个py文件
1.激活虚拟环境
    进入项目的目录
        cd C:\\Users\\Windows\\PycharmProjects\\movieProject
    激活虚拟环境
        .venv\Scripts\activate
2.安装依赖（如果是首次运行项目，需要安装依赖）
    pip install -r requirements.txt
3.运行爬虫
    python spiders/douban_spider.py
4.对源数据进行清洗操作
    python data_processing/cleaner.py
    (在启动之前，别忘了要安装库)
5.已经拿到了清洗之后的数据了，需要对清洗之后的数据进行数据分析了
    python data_processing/analyzer.py
    (在启动之前，别忘了要安装库)
'''