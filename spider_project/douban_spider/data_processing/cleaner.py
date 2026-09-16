"""
豆瓣电影数据清洗
"""
# 引入Pandas数据分析库，别名为pd
import pandas as pd
# 用于数据清洗中的数值处理、缺失值填充、异常值检测等操作
import numpy as np
import re
# 路径操作，可替换os.path
from pathlib import Path
from datetime import datetime

class DouBanCleaner(object):
    def __init__(self):
        # 获取当前文件的上两级目录(项目根目录)
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.raw_dir = self.data_dir / "raw"
        self.cleaned_dir = self.data_dir / "cleaned"
        # parents=True:如果父目录不存在，一并创建
        # exist_ok=True:如果目录已存在，不抛出错误
        self.cleaned_dir.mkdir(parents=True, exist_ok=True)
        # 设置原始CSV文件路径（原始数据）
        self.csv_raw_path = self.raw_dir / "douban_movies_raw.csv"
        # 清洗后的Excel文件路径
        # 将原始csv文件数据清洗处理后，保存到excel格式的指定目录
        self.xlsx_path = self.cleaned_dir / "douban_movies_cleaned.xlsx"
        # 清洗过后的csv文件
        self.csv_path = self.cleaned_dir / "douban_movies_cleaned.csv"

        # 国家地区映射
        self.country_mapping = {
            'hongkong': '中国香港', 'hk': '中国香港',  # 简写
            'taiwan': '中国台湾', 'tw': '中国台湾',
            'mainland china': '中国大陆', 'china': '中国大陆', 'cn': '中国大陆',
            'usa': '美国', 'america': '美国', 'united states': '美国', 'us': '美国',
            'japan': '日本', 'jp': '日本',
            'korea': '韩国', 'south korea': '韩国', 'kr': '韩国',
            'france': '法国', 'fr': '法国',
            'germany': '德国', 'de': '德国',
            'italy': '意大利', 'it': '意大利',
            'spain': '西班牙', 'es': '西班牙',
            'uk': '英国', 'united kingdom': '英国', 'gb': '英国',
            'india': '印度', 'in': '印度',
            'russia': '俄罗斯', 'ru': '俄罗斯',
            'australia': '澳大利亚', 'au': '澳大利亚',
            'canada': '加拿大', 'ca': '加拿大',
            'brazil': '巴西', 'br': '巴西',
            'mexico': '墨西哥', 'mx': '墨西哥',
            'switzerland': '瑞士', 'swiss': '瑞士',
            'sweden': '瑞典', 'se': '瑞典',
            'denmark': '丹麦', 'dk': '丹麦',
            'norway': '挪威', 'no': '挪威',
            'finland': '芬兰', 'fi': '芬兰',
            'netherlands': '荷兰', 'nl': '荷兰',
            'belgium': '比利时', 'be': '比利时',
            'austria': '奥地利', 'at': '奥地利',
            'thailand': '泰国', 'th': '泰国',
            'vietnam': '越南', 'vn': '越南',
            'malaysia': '马来西亚', 'my': '马来西亚',
            'singapore': '新加坡', 'sg': '新加坡',
            'iran': '伊朗', 'ir': '伊朗',
            'turkey': '土耳其', 'tr': '土耳其',
            'poland': '波兰', 'pl': '波兰',
            'czech': '捷克', 'cz': '捷克',
            'hungary': '匈牙利', 'hu': '匈牙利',
            'south africa': '南非', 'za': '南非',
            'egypt': '埃及', 'eg': '埃及',
            'argentina': '阿根廷', 'ar': '阿根廷',
            'chile': '智利', 'cl': '智利',
            'new zealand': '新西兰', 'nz': '新西兰',
            'ireland': '爱尔兰', 'ie': '爱尔兰',
            'portugal': '葡萄牙', 'pt': '葡萄牙',
            'greece': '希腊', 'gr': '希腊',
            'ukraine': '乌克兰', 'ua': '乌克兰',
            'colombia': '哥伦比亚', 'co': '哥伦比亚',
            'peru': '秘鲁', 'pe': '秘鲁',
            'venezuela': '委内瑞拉', 've': '委内瑞拉',
            'pakistan': '巴基斯坦', 'pk': '巴基斯坦',
            'bangladesh': '孟加拉国', 'bd': '孟加拉国',
            'philippines': '菲律宾', 'ph': '菲律宾',
            'indonesia': '印度尼西亚', 'id': '印度尼西亚',
            'israel': '以色列', 'il': '以色列',
            'saudi arabia': '沙特阿拉伯', 'sa': '沙特阿拉伯',
            'uae': '阿联酋', 'united arab emirates': '阿联酋'
        }
        # 有效国家地区列表（确保只有公认国家地区名称被保留）
        self.valid_countries = {
            '中国大陆', '中国香港', '中国台湾', '中国澳门', '香港', '台湾', '澳门',
            '美国', '日本', '韩国', '法国', '英国', '德国', '意大利', '加拿大', '澳大利亚',
            '印度', '俄罗斯', '西班牙', '巴西', '墨西哥', '瑞典', '丹麦', '挪威', '芬兰',
            '荷兰', '比利时', '瑞士', '奥地利', '泰国', '越南', '马来西亚', '新加坡',
            '伊朗', '土耳其', '波兰', '捷克', '匈牙利', '南非', '埃及', '阿根廷',
            '智利', '新西兰', '爱尔兰', '葡萄牙', '希腊', '乌克兰', '哥伦比亚',
            '秘鲁', '委内瑞拉', '巴基斯坦', '孟加拉国', '菲律宾', '印度尼西亚',
            '以色列', '沙特阿拉伯', '阿联酋', '黎巴嫩', '卡塔尔'
        }
        # 有效电影类型列表
        self.valid_genres = {
            '剧情', '喜剧', '爱情', '动作', '科幻', '动画', '悬疑', '惊悚', '恐怖',
            '犯罪', '奇幻', '冒险', '家庭', '战争', '历史', '传记', '运动', '音乐',
            '歌舞', '纪录片', '武侠', '古装', '黑色电影', '短片', '情色', '儿童',
            '灾难', '西部', '舞台艺术', '脱口秀', '真人秀', '同性', '其他'
        }

    def load_data(self):
        """加载数据"""
        try:
            # self:当前DataCleaner实例
            # csv_raw_path:在__init__初始化的属性，存储原始数据文件路径
            # （读取爬虫爬取的未处理数据，是数据清洗流程的输入源）
            df = pd.read_csv(self.csv_raw_path, encoding='utf-8')
            print(f"加载成功: {len(df)} 行, {len(df.columns)} 列")
            print(f"列名: {list(df.columns)}")
            return df
        except Exception as e:
            print(f"加载失败: {e}")
            return pd.DataFrame()

    def is_truncated_person_name(self, name_str):
        """检查人名是否被截断"""
        # name_str 通常指人名(导演名或演员名)
        # isna 判断是否为空（缺失值）
        # str(name_str).strip() 转为字符串，并去除空白
        # not ... 是否为空字符串
        if pd.isna(name_str) or not str(name_str).strip():
            # 无效的名字
            return False
        name_str = str(name_str)
        # 定义检测截断名字的正则表达式模式列表
        truncation_patterns = [
            r'\.{2,}$',  # 匹配以多个点结尾(如"张三...")
            r'…$',  # 匹配以省略号结尾
            r'[^\w\s\/、|]$',  # 匹配以非正常（奇怪）字符结尾
            r'[^\w\s\/、|]\s*$',  # 匹配以奇怪字符和空格结尾
        ]
        # 遍历所有截断模式，检查名字是否被截断
        for pattern in truncation_patterns:
            # 在名字中搜索匹配
            if re.search(pattern, name_str):
                # 表示名字被截断
                return True
        return False

    # names_str:待清洗的人名字段值
    # （field_name:标识字段类型）
    # 例如清洗"演员"字段时，field_name="演员"，便于追踪是哪个字段在处理
    def repair_person_names_simple(self, names_str, field_name):
        """简单修复人名截断问题"""
        if pd.isna(names_str) or not str(names_str).strip():
            # 等价于 if field_name == '演员':return "" else: return "未知"
            return "" if field_name == '演员' else "未知"
        names_str = str(names_str).strip()

        # 如果没有人名或已经是空的
        if not names_str or names_str in ['未知', 'N/A', 'n/a', 'null', 'None']:
            return "" if field_name == '演员' else "未知"
        # 统一多种分隔符为斜杠
        for sep in ['、', '|', '，', ',', ';', '；']:  # 遍历常见分隔符
            # 将所有分隔符替换为/
            names_str = names_str.replace(sep, '/')
        # 分割并清理每个人名
        name_list = [name.strip() for name in names_str.split('/') if name.strip()]

        cleaned_names = []
        for name in name_list:
            # 清理截断标记
            if self.is_truncated_person_name(name):
                # 移除...等截断标记
                # 将以多个点结尾的人名，替换为空字符串，例如：'张三...'替换成'张三'
                name = re.sub(r'\.{2,}$', '', name)
                name = re.sub(r'…$', '', name)
                # 匹配非字母数字、非空白、非中文、非特殊符号的字符
                # [\u4e00-\u9fff]:匹配任意一个中文字符
                name = re.sub(r'[^\w\s\u4e00-\u9fff·\-\.]$', '', name)  # 移除结尾的非法字符
                name = name.strip()
                # 如果清理后名字太短，可能不完整
                if len(name) < 2:
                    # 跳过当前循环，当前结果不添加到结果列表
                    continue
            # 检查名字是否合理
            if name and len(name) >= 2:
                # 去重
                if name not in cleaned_names:
                    cleaned_names.append(name)
        # 返回处理结果
        if not cleaned_names:  # 检查列表是否为空（为空）
            # 演员为空 → 返回""；导演为空 → 返回"未知"
            # field_name == '演员' 检查的是传入的参数，不是列表内容
            return "" if field_name == '演员' else "未知"
        return ' / '.join(cleaned_names)  # 以" / "为分隔符拼接列表元素

    def clean_director_and_actors(self, df):
        """清洗导演和演员字段"""
        df_cleaned = df.copy()
        # 清洗导演
        if '导演' in df_cleaned.columns:
            # items():返回(索引,值)元组
            for idx, value in df_cleaned['导演'].items():
                if pd.notna(value):
                    # 调用清洗方法处理原始值
                    # 第一个参（value）表示当前行的导演名字符串
                    # 第二个参（'导演'）表示当前清洗的是导演
                    cleaned = self.repair_person_names_simple(value, '导演')
                    # 将清洗后的导演名，写回数据框对应位置
                    df_cleaned.at[idx, '导演'] = cleaned
        # 清洗演员
        if '演员' in df_cleaned.columns:
            for idx, value in df_cleaned['演员'].items():
                if pd.notna(value):
                    cleaned = self.repair_person_names_simple(value, '演员')
                    df_cleaned.at[idx, '演员'] = cleaned
        return df_cleaned

    def clean_country(self, df):
        """清洗国家地区字段"""
        if '国家地区' not in df.columns:
            # 调用者需要，获取清洗后的数据
            return df
        df_cleaned = df.copy()
        # df_cleaned['国家地区'] 表示清理后的数据
        for idx, value in enumerate(df_cleaned['国家地区']):
            if pd.isna(value) or not str(value).strip():
                # 为空，填充默认值
                df_cleaned.at[idx, '国家地区'] = "未知"
                continue
            original = str(value).strip()

            # 检查是否是纯数字年份格式
            year_pattern = r'^\s*\d{4}\s*(/\s*\d{4}\s*)?$'
            # 说明原始值是年份，不是国家。例如original = "2026"
            if re.match(year_pattern, original):  # 匹配成功
                # 说明这个字段存的是"1994"(年份)，而不是国家地区
                df_cleaned.at[idx, '国家地区'] = "未知"
                continue

            # 使用多种分隔符分割
            # 先尝试空格分割（处理"美国 英国 加拿大"这样的格式）
            # 然后尝试斜杠分割
            parts = []
            # 按一个或多个空白字符分割
            # original是国家地区（其值可能是：'美国'-单个 '美国 日本'-多个
            # '中国香港'-地区 'USA UK'-英文）
            temp_parts = re.split(r'\s+', original)
            for temp_part in temp_parts:
                # 如果部分包含斜杠，进一步分割
                if '/' in temp_part or '、' in temp_part:
                    # r'[/、]':匹配/或、
                    # split 按分隔符拆分成列表
                    # temp_part 待拆分对象
                    sub_parts = re.split(r'[/、]', temp_part)
                    parts.extend(sub_parts)
                else:
                    # 分割产生空列表
                    # 添加未分割的原始数据
                    parts.append(temp_part)

            valid_parts = []
            # 遍历分割后的每个国家地区
            for part in parts:
                part = part.strip()
                # 如果分割后的国家地区为空，跳过
                # （如"美国//日本"分割后就是空值）
                if not part:
                    continue
                # 检查是否是纯年份或年份范围
                if re.match(r'^\d{4}(/\d{4})?$', part):
                    continue
                # 移除可能的年份数字（如"美国2010"清理为"美国"）                    # 但保留国家名称
                # r'\s*\d{4}\s*':匹配4位年份及其前后空白
                # 替换为空字符串
                cleaned_part = re.sub(r'\s*\d{4}\s*', '', part)
                cleaned_part = cleaned_part.strip()
                # 如果移除年份后什么都没有，尝试保留原始部分
                # 例如这个国家不在字典中（新西兰 或 空字符串）
                if not cleaned_part:  # True，为空
                    # 保留原始值
                    cleaned_part = part
                # 应用映射（使用小写进行匹配）
                lower_part = cleaned_part.lower()
                # 通过小写形式查找国家映射,实现大小写不敏感的标准化
                # 检查是否在映射字典中
                if lower_part in self.country_mapping:
                    # 获取标准中文名（如将"USA"、"usa"、"UsA"统一映射为"美国"）
                    cleaned_part = self.country_mapping[lower_part]
                # 特殊处理一些常见的中文名称
                # 只要其中一个成立，整个条件就为 True
                elif 'hongkong' in lower_part or 'hk' in lower_part:
                    # 给变量设值
                    cleaned_part = '中国香港'
                elif 'taiwan' in lower_part or 'tw' in lower_part:
                    cleaned_part = '中国台湾'
                elif 'macau' in lower_part or 'macao' in lower_part:
                    cleaned_part = '中国澳门'
                elif 'china' in lower_part or 'cn' in lower_part:
                    cleaned_part = '中国大陆'
                # 检查一个清洗后的地区名称是否有效
                if cleaned_part in self.valid_countries:
                    # 有效且尚未被记录
                    if cleaned_part not in valid_parts:
                        # 添加到结果列表中
                        valid_parts.append(cleaned_part)
                else:
                    # 模糊匹配中国地区
                    # for...in 遍历特定地区的列表
                    # 当keyword存在于cleaned_part这个字符串中时，才保留这个词
                    # any() 检查括号内，可迭代对象中，是否存在至少一个为真（True）的元素
                    if any(keyword in cleaned_part for keyword in ['中国', '香港', '台湾', '澳门']):
                        # upper() 转成大写
                        if '香港' in cleaned_part or 'HK' in cleaned_part.upper():
                            if '中国香港' not in valid_parts:
                                valid_parts.append('中国香港')
                        elif '台湾' in cleaned_part or 'TW' in cleaned_part.upper():
                            if '中国台湾' not in valid_parts:
                                valid_parts.append('中国台湾')
                        elif '澳门' in cleaned_part or 'MACAU' in cleaned_part.upper() or 'MACAO' in cleaned_part.upper():
                            if '中国澳门' not in valid_parts:
                                valid_parts.append('中国澳门')
                        else:
                            if '中国大陆' not in valid_parts:
                                valid_parts.append('中国大陆')
                    # 检查常见的英文国家名
                    elif 'USA' in cleaned_part.upper() or 'AMERICA' in cleaned_part.upper():
                        if '美国' not in valid_parts:
                            valid_parts.append('美国')
                    elif 'JAPAN' in cleaned_part.upper():
                        if '日本' not in valid_parts:
                            valid_parts.append('日本')
                    elif 'KOREA' in cleaned_part.upper():
                        if '韩国' not in valid_parts:
                            valid_parts.append('韩国')
                    elif 'FRANCE' in cleaned_part.upper():
                        if '法国' not in valid_parts:
                            valid_parts.append('法国')
                    elif 'GERMANY' in cleaned_part.upper() or 'DEUTSCHLAND' in cleaned_part.upper():
                        if '德国' not in valid_parts:
                            valid_parts.append('德国')
                    elif 'ITALY' in cleaned_part.upper():
                        if '意大利' not in valid_parts:
                            valid_parts.append('意大利')
                    elif 'SPAIN' in cleaned_part.upper():
                        if '西班牙' not in valid_parts:
                            valid_parts.append('西班牙')
                    elif 'UK' in cleaned_part.upper() or 'UNITED KINGDOM' in cleaned_part.upper():
                        if '英国' not in valid_parts:
                            valid_parts.append('英国')
                    elif 'CANADA' in cleaned_part.upper():
                        if '加拿大' not in valid_parts:
                            valid_parts.append('加拿大')
                    elif 'AUSTRALIA' in cleaned_part.upper():
                        if '澳大利亚' not in valid_parts:
                            valid_parts.append('澳大利亚')
                    elif 'INDIA' in cleaned_part.upper():
                        if '印度' not in valid_parts:
                            valid_parts.append('印度')
                    elif 'RUSSIA' in cleaned_part.upper():
                        if '俄罗斯' not in valid_parts:
                            valid_parts.append('俄罗斯')

            # 去重并保持原始顺序
            # set() 创建一个空的集合
            seen = set()
            final_parts = []
            # 遍历列表
            for part in valid_parts:
                # 在seen中不存在part
                if part not in seen:
                    # 集合中添加
                    seen.add(part)
                    # 将指定元素，添加到 列表 末尾
                    final_parts.append(part)
            if final_parts:
                # 清洗后去重的国家地区列表final_parts
                # 用" / "作为分隔符，拼接成字符串（如"美国 / 日本 / 韩国"）
                # 写回数据框df_cleaned第idx行的"国家地区"列
                df_cleaned.at[idx, '国家地区'] = ' / '.join(final_parts)
            else:
                df_cleaned.at[idx, '国家地区'] = "未知"
        return df_cleaned

    def clean_year(self, df):
        # df中没有“上映年份”这一列
        if '上映年份' not in df.columns:
            # 当前的DataFrame直接返回
            return df
        df_cleaned = df.copy()
        # 按顺序遍历df_cleaned表格中“上映年份”这一列的每一行数据（拿到行号和值）
        for idx, value in enumerate(df_cleaned['上映年份']):
            # 检测数据是否为“非数值”或缺失值
            if pd.isna(value):
                # 将对应行“上映年份”字段，修改为字符串"未知"
                df_cleaned.at[idx, '上映年份'] = "未知"
                # 跳到下一行数据继续处理
                continue
            original = str(value)
            # 从原始字符串中提取一个4位数的年份（匹配1900-2099之间）
            # \d{2} 匹配任意两个数字
            year_match = re.search(r'(19\d{2}|20\d{2})', original)
            if year_match:
                # group()是捕获组  1是编号
                # 一个()括起来的部分，表示一个捕获组
                # 将某一部分单独拎出来
                # 这里只有一个()，所以这里group(0)和group(1)效果一样
                year = int(year_match.group(1))
                # 获取当前年份
                current_year = datetime.now().year
                # 为什么是1888 -- 世界上第一部电影大约是1888年拍摄的
                # 为什么+2 -- 电影提前定档（例如现在2026，已经公布2027或2028年的电影计划）
                if 1888 <= year <= current_year + 2:
                    df_cleaned.at[idx, '上映年份'] = year
                else:
                    df_cleaned.at[idx, '上映年份'] = "未知"
            else:
                df_cleaned.at[idx, '上映年份'] = "未知"
        return df_cleaned

    def clean_genre(self, df):
        if '电影类型' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx, value in enumerate(df_cleaned['电影类型']):
            if pd.isna(value):
                df_cleaned.at[idx, '电影类型'] = "未知"
                continue
            original = str(value).strip()
            # 替换各种分隔符为斜杠
            for sep in [' ', '、', '|', '，', ',', ';', '；']:
                original = original.replace(sep, '/')
            parts = [p.strip() for p in original.split('/') if p.strip()]

            valid_parts = []
            for part in parts:
                # valid_genres 表示合法/有效的电影类型集合
                if part in self.valid_genres:
                    valid_parts.append(part)
            if valid_parts:
                # 去重
                seen = set()
                unique_parts = []
                for part in valid_parts:
                    if part not in seen:
                        seen.add(part)
                        unique_parts.append(part)
                df_cleaned.at[idx, '电影类型'] = '/'.join(unique_parts)
            else:
                df_cleaned.at[idx, '电影类型'] = "未知"
        return df_cleaned

    def clean_rating(self, df):
        """清洗评分"""
        if '评分' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx, value in enumerate(df_cleaned['评分']):
            # value为空，返回true；不为空，就跳过
            if pd.isna(value):
                # 显式地将DataFrame中，对应位置的值，重新赋值为标准的NumPy空值(np.nan)
                # 为什么这么做？在实际数据清洗中，空值可能长得很奇怪
                # 虽然isna()能识别空值，但还不是标准的数字类型空值
                df_cleaned.at[idx, '评分'] = np.nan
                continue
            try:
                # 将评分转为浮点数数据类型
                rating = float(str(value).strip())
                if 0 <= rating <= 10:
                    # 保留一位小数
                    df_cleaned.at[idx, '评分'] = round(rating, 1)
                else:
                    df_cleaned.at[idx, '评分'] = np.nan
            except:
                df_cleaned.at[idx, '评分'] = np.nan
        return df_cleaned

    def clean_votes(self, df):
        """清洗评价人数"""
        if '评价人数' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx,value in enumerate(df_cleaned['评价人数']):
            if pd.isna(value):
                # 从数据底层（不再是“未知”或“数据丢失”），将缺失值彻底，替换成了数字0
                df_cleaned.at[idx, '评价人数'] = 0
                continue
            original = str(value)
            # 处理"万"单位
            if '万' in original:
                try:
                    # 匹配由「数字」或「小数点」组成的、长度≥1的连续子串
                    num_part = re.search(r'[\d\.]+', original)
                    if num_part:
                        # group()匹配全部
                        num_value = float(num_part.group()) * 10000
                        df_cleaned.at[idx, '评价人数'] = int(num_value)
                        continue
                except:
                    pass
            try:
                # ^：放在方括号[]的第一位，表示“取反”或“非”
                # [^\d]：合起来是 “匹配任何不是数字的字符”
                # 将匹配到的结果转为空字符串
                clean_str = re.sub(r'[^\d]', '', original)
                if clean_str:
                    # int()函数，无法直接处理，带小数点的字符串
                    # 先转浮点，再转整数
                    votes = int(float(clean_str))
                    # max(a,b) 取两个数中的较大者
                    # 如果votes > 0取votes；否则取0
                    df_cleaned.at[idx, '评价人数'] = max(votes, 0)
                else:
                    df_cleaned.at[idx, '评价人数'] = 0
            except:
                df_cleaned.at[idx, '评价人数'] = 0
        return df_cleaned

    def clean_text_field(self, df, field_name):
        """清洗文本字段"""
        if field_name not in df.columns:
            return df
        df_cleaned = df.copy()
        # 将数据列中的缺失值，替换为空字符串，并将整列数据，强制转换为字符串类型
        # fillna('')：将缺失值替换为空字符串
        # astype(str)：将数据类型转换为字符串
        df_cleaned[field_name] = df_cleaned[field_name].fillna('').astype(str).str.strip()
        return df_cleaned

    def clean_data_quality(self, df):
        """清洗数据质量评分"""
        if '数据质量评分' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx,value in enumerate(df_cleaned['数据质量评分']):
            if pd.isna(value):
                df_cleaned.at[idx, '数据质量评分'] = 0
                continue
            try:
                score = int(float(str(value).strip()))
                if 0 <= score <= 100:
                    df_cleaned.at[idx, '数据质量评分'] = score
                else:
                    df_cleaned.at[idx, '数据质量评分'] = 0
            except:
                df_cleaned.at[idx, '数据质量评分'] = 0
        return df_cleaned

    def handle_missing_values(self, df):
        """处理缺失值"""
        df_cleaned = df.copy()
        # 填充数值字段
        for col in ['评分', '评价人数']:
            if col in df_cleaned.columns:
                # errors是异常处理开关
                # errors='raise'（默认值）：遇到无法转换的“坏数据”，则抛出异常
                # errors='coerce'：遇到能转成数字的就正常转换；遇到无法转换的“坏数据”，则将其强制替换为NaN
                # errors='ignore'：能转就转，不能转就保持原样
                df_cleaned[col] = pd.to_numeric(df_cleaned[col], errors='coerce')
                # 用该列的“中位数”来填补空值（NaN）
                # fillna() -- 检查df_cleaned[col]这一列，把所有NaN（缺失值）替换为括号里指定的值
                # notna() -- 是否至少存在一个非空值
                # any() -- 只要有一个为 True 就返回 True
                '''
                相当于如下写法
                if df_cleaned[col].notna().any():
                    fill_value = df_cleaned[col].median()
                else:
                    fill_value = 0
                '''
                df_cleaned[col] = df_cleaned[col].fillna(df_cleaned[col].median() if df_cleaned[col].notna().any() else 0)
        # 填充分类字段
        for col in ['导演', '演员', '电影类型', '国家地区', '上映年份']:
            if col in df_cleaned.columns:
                # 把所有NaN值，替换为'未知'
                df_cleaned[col] = df_cleaned[col].fillna('未知')
        # 填充文本字段
        for col in ['简介', '别名']:
            if col in df_cleaned.columns:
                df_cleaned[col] = df_cleaned[col].fillna('')
        return df_cleaned

    def report_director_actor_issues(self, df):
        """报告导演和演员字段的截断问题"""
        print("=" * 60)
        print("导演和演员字段截断问题检测")
        print("=" * 60)

        director_issues = []
        actor_issues = []

        if '导演' in df.columns:
            # 生成一个包含“行索引”和“对应单元格值”的迭代器
            # （导演列下存在多个值，用items迭代）
            for idx, value in df['导演'].items():
                if pd.notna(value) and self.is_truncated_person_name(value):
                    # str(value)[:50] 截取前50个字符
                    director_issues.append((idx, str(value)[:50]))
        if '演员' in df.columns:
            for idx, value in df['演员'].items():
                if pd.notna(value) and self.is_truncated_person_name(value):
                    actor_issues.append((idx, str(value)[:50]))
        print(f"导演字段问题: {len(director_issues)} 行")
        if director_issues:
            print("示例：")
            # 遍历列表前5个元素，获取这三个信息：当前的计数序号i、元素索引idx、以及元素值val
            # [:5] 只取前5条数据
            for i, (idx, val) in enumerate(director_issues[:5]):
                print(f"  行 {idx}: {val}")
        print(f"\n演员字段问题: {len(actor_issues)} 行")
        if actor_issues:
            print("示例：")
            for i, (idx, val) in enumerate(actor_issues[:5]):
                print(f"  行 {idx}: {val}")
        # 检查两个列表是否都为空。如果都为空，则条件成立（返回True）
        if not director_issues and not actor_issues:
            print("未发现截断问题")
        print("=" * 60)
        return len(director_issues), len(actor_issues)

    """调试国家地区数据清洗"""
    def debug_country_cleaning(self, df, num_rows=10):
        print("\n" + "=" * 60)
        print("国家地区字段清洗调试")
        print("=" * 60)

        if '国家地区' not in df.columns:
            print("数据中没有'国家地区'字段")
            return

        print(f"前{num_rows}行数据示例：")
        # 生成一个遍历范围，确保循环次数既不超过“指定的行数”，也不超过“数据表实际的总行数”
        # min()只取一个值
        # 理解：在一条限速120km/h高速公路上开车，今天下大雨，交警临时规定最高只能开80km/h
        # （只返回一个80的值，但同时确保了：没有超过车子本身的极限120；没有违反交警的规定80）
        for idx in range(min(num_rows, len(df))):
            # pd.notna() 判断国家地区的值是不是空值，不空返回True，否则返回False
            # 如果判断为True，执行str()，表示为将这个值，强制转换为字符串
            original = str(df.at[idx, '国家地区']) if pd.notna(df.at[idx, '国家地区']) else ""
            cleaned = str(df.at[idx, '国家地区']) if pd.notna(df.at[idx, '国家地区']) else ""
            print(f"  行 {idx}: 原始='{original}' -> 清洗后='{cleaned}'")
        print("=" * 60)

    """（不是调试）正常执行清洗流程"""
    def run_cleaning(self):
        print("开始豆瓣电影数据清洗...")
        # 加载数据
        df = self.load_data()
        # 加载的数据为空
        if df.empty:
            # 创建一个没有任何行、也没有任何列的空表格
            return pd.DataFrame()
        # 显示前几行的原始国家数据
        print("\n原始数据前10行国家地区信息：")
        for idx in range(min(10, len(df))):
            print(f"行 {idx}: '{df.at[idx, '电影名']}' - 国家地区: '{df.at[idx, '国家地区']}'")
        # 报告原始问题
        original_dir_issues, original_act_issues = self.report_director_actor_issues(df)
        # 执行清洗
        print("\n开始清洗处理...")
        df = self.clean_director_and_actors(df)
        df = self.clean_year(df)
        df = self.clean_country(df)
        df = self.clean_genre(df)
        df = self.clean_rating(df)
        df = self.clean_votes(df)
        # 如果存在数据质量评分列，清洗它
        if '数据质量评分' in df.columns:
            df = self.clean_data_quality(df)
        # 清洗其他文本字段
        for field in ['电影名', '简介', '别名']:
            df = self.clean_text_field(df, field)
        # 处理缺失值
        df = self.handle_missing_values(df)
        # 显示清洗后的前几行国家数据
        print("\n清洗后数据前10行国家地区信息：")
        for idx in range(min(10, len(df))):
            print(f"行 {idx}: '{df.at[idx, '电影名']}' - 国家地区: '{df.at[idx, '国家地区']}'")
        # 报告清洗后的问题
        print("\n清洗后：")
        # 检测问题的方法
        # 变量为清洗后剩余问题数
        final_dir_issues, final_act_issues = self.report_director_actor_issues(df)
        # 导演和演员字段中，存在的问题数量
        if original_dir_issues > 0 or original_act_issues > 0:
            print(f"\n修复统计：")
            print(f"  导演字段: 修复了 {original_dir_issues - final_dir_issues}/{original_dir_issues} 个问题")
            print(f"  演员字段: 修复了 {original_act_issues - final_act_issues}/{original_act_issues} 个问题")

        # 保存数据为 Excel
        df.to_excel(self.xlsx_path, index=False)
        print(f"Excel 文件已保存至: {self.xlsx_path}")
        # 保存数据为 csv
        df.to_csv(self.csv_path, index=False, encoding='utf-8-sig')
        print(f"CSV 文件已保存至: {self.csv_path}")

        return df

if __name__ == "__main__":
    cleaner = DouBanCleaner()
    df = cleaner.run_cleaning()
