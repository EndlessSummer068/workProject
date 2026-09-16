"""
古诗词数据清洗
"""
import pandas as pd
import numpy as np
import re
from pathlib import Path

class PoetryCleaner(object):
    def __init__(self):
        # 获取当前文件的上两级目录(项目根目录)
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.raw_dir = self.data_dir / "raw"
        self.cleaned_dir = self.data_dir / "cleaned"
        self.cleaned_dir.mkdir(parents=True, exist_ok=True)

        # 原始 CSV 路径（爬虫爬下来的）
        self.csv_raw_path = self.raw_dir / "poetry_1000.csv"
        # 清洗后输出路径
        self.xlsx_path = self.cleaned_dir / "poetry_cleaned.xlsx"
        self.csv_path = self.cleaned_dir / "poetry_cleaned.csv"

        # ==================== 1. 朝代标准化映射 ====================
        # 先秦、两汉、魏晋、南北朝、隋代、唐代、五代、宋代、金朝、元代、明代、清代
        self.dynasty_mapping = {
            '先秦': '先秦', '秦': '先秦', '秦代': '先秦',
            '两汉': '两汉', '汉': '两汉', '汉代': '两汉', '东汉': '两汉', '西汉': '两汉',
            '魏晋': '魏晋', '三国': '魏晋', '魏': '魏晋', '蜀': '魏晋', '吴': '魏晋',
            '南北朝': '南北朝',
            '隋': '隋代', '隋代': '隋代', '隋朝': '隋代',
            '唐': '唐代', '唐代': '唐代', '唐朝': '唐代', '盛唐': '唐代', '晚唐': '唐代', '初唐': '唐代',
            '中唐': '唐代',
            '五代': '五代', '五代十国': '五代',
            '宋': '宋代', '宋代': '宋代', '宋朝': '宋代', '北宋': '宋代', '南宋': '宋代',
            '金': '金朝', '金朝': '金朝', '金代': '金朝',
            '元': '元代', '元代': '元代', '元朝': '元代',
            '明': '明代', '明代': '明代', '明朝': '明代',
            '清': '清代', '清代': '清代', '清朝': '清代',
            '未知': '未知', '不详': '未知', '': '未知'
        }

        # ==================== 2. 类型（标签）标准化集合 ====================
        self.valid_tags = {
            '写景', '咏物', '春天', '菊花', '夏天', '柳树', '写马', '秋天', '月亮', '田园',
            '冬天', '山水', '边塞', '写雨', '写山', '地名', '写雪', '写水', '抒情', '写风',
            '长江', '爱国', '写花', '离别', '梅花', '送别', '荷花', '写鸟', '思乡', '读书',
            '爱情', '思念', '励志', '惜时', '哲理', '婉约', '豪放', '闺怨', '悼亡', '诗经',
            '民谣', '写人', '节日', '春节', '母亲', '友情', '战争', '楚辞', '乐府', '怀古',
            '忧民', '怀人', '赞美', '女子', '叙事', '故事', '生活', '孤独', '元宵节', '寒食节',
            '清明节', '端午节', '七夕节', '中秋节', '重阳节', '高中古诗', '忧国忧民', '咏史怀古',
            '宋词精选', '小学古诗', '初中古诗', '古文观止', '小学文言文', '初中文言文',
            '高中文言文', '古诗十九首', '唐诗三百首', '古诗三百首', '宋词三百首'
        }

        # ==================== 3. 作者标准化集合 ====================
        self.valid_authors = {
            '李白', '杜甫', '苏轼', '王维', '杜牧', '曹操', '陆游', '李贺', '屈原', '李煜',
            '韩愈', '岑参', '高适', '程垓', '贾岛', '柳永', '曹植', '王勃', '元稹', '孟郊',
            '岳飞', '齐己', '罗隐', '贾休', '韦庄', '张籍', '张祜', '王建', '晏殊', '皎然',
            '许浑', '卢纶', '姚合', '秦观', '郑谷', '钱起', '郑燮', '张说', '朱熹', '张炎',
            '韩偓', '方干', '李峤', '赵嘏', '贺铸', '白居易', '辛弃疾', '李清照', '刘禹锡',
            '李商隐', '陶渊明', '孟浩然', '柳宗元', '范仲淹', '王安石', '陆龟蒙', '晏几道',
            '欧阳修', '黄庭坚', '周邦彦', '韦应物', '司马迁', '杜荀鹤', '皇甫冉', '温庭筠',
            '刘长卿', '卓文君', '吴文英', '文天祥', '王昌龄', '马致远', '刘辰翁', '杨万里',
            '皮日休', '左丘明', '诸葛亮'
        }

    # ==================== 加载 ====================
    def load_data(self):
        """加载原始数据"""
        try:
            df = pd.read_csv(self.csv_raw_path, encoding='utf-8')
            print(f"加载成功: {len(df)} 行, {len(df.columns)} 列")
            print(f"列名: {list(df.columns)}")
            return df
        except Exception as e:
            print(f"加载失败: {e}")
            return pd.DataFrame()

    # ==================== 标题清洗 ====================
    def clean_title(self, df):
        """清洗标题"""
        if '标题' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx, value in df_cleaned['标题'].items():
            if pd.isna(value) or not str(value).strip():
                df_cleaned.at[idx, '标题'] = '无题'
                continue
            title = str(value).strip()
            # 去掉常见的前后缀噪音
            title = re.sub(r'\s+', ' ', title)
            df_cleaned.at[idx, '标题'] = title
        return df_cleaned

    # ==================== 作者清洗 ====================
    def is_truncated_person_name(self, name_str):
        """检查作者名是否被截断（沿用豆瓣的判定逻辑）"""
        if pd.isna(name_str) or not str(name_str).strip():
            return False
        name_str = str(name_str)
        truncation_patterns = [
            r'\.{2,}$',
            r'…$',
            r'[^\w\s\/、|]$',
            r'[^\w\s\/、|]\s*$',
        ]
        for pattern in truncation_patterns:
            if re.search(pattern, name_str):
                return True
        return False

    def clean_author(self, df):
        """清洗作者字段，对齐到标准作者列表"""
        if '作者' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx, value in df_cleaned['作者'].items():
            if pd.isna(value) or not str(value).strip():
                df_cleaned.at[idx, '作者'] = '佚名'
                continue

            name = str(value).strip()
            # 去掉截断标记
            name = re.sub(r'\.{2,}$', '', name).strip()
            name = re.sub(r'…$', '', name).strip()

            # 如果名字在标准作者库里，直接保留
            if name in self.valid_authors:
                df_cleaned.at[idx, '作者'] = name
            # 如果不在，说明可能是网站新增的作者，或者爬取时有脏数据
            # 策略：保留原名（因为诗人太多了，不可能只有图片里这些），但过滤掉明显无效的
            elif name in ['佚名', '无名氏', '不详', '未知', 'N/A', 'n/a', 'null', 'None', '']:
                df_cleaned.at[idx, '作者'] = '佚名'
            else:
                # 保留原始名字，方便你后续发现新诗人
                df_cleaned.at[idx, '作者'] = name
        return df_cleaned

    # ==================== 朝代清洗 ====================
    def clean_dynasty(self, df):
        """清洗朝代字段，严格映射到 12 个标准朝代"""
        if '朝代' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx, value in df_cleaned['朝代'].items():
            if pd.isna(value) or not str(value).strip():
                df_cleaned.at[idx, '朝代'] = '未知'
                continue

            # 去掉括号、空白
            dynasty = str(value).strip().strip('〔〕【】[]（）()').strip()

            # 严格映射到标准词
            if dynasty in self.dynasty_mapping:
                df_cleaned.at[idx, '朝代'] = self.dynasty_mapping[dynasty]
            else:
                # 认不出来就统一归为未知（图片里没有这个朝代）
                df_cleaned.at[idx, '朝代'] = '未知'
        return df_cleaned

    # ==================== 正文清洗 ====================
    def clean_content(self, df):
        """清洗正文"""
        if '正文' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx, value in df_cleaned['正文'].items():
            if pd.isna(value) or not str(value).strip():
                df_cleaned.at[idx, '正文'] = ''
                continue
            content = str(value)
            # 1. 把 \r\n、\t、全角空格统一成半角空格
            content = content.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ')
            content = content.replace('\u3000', ' ')
            # 2. 压缩连续空白为一个空格
            content = re.sub(r'\s+', ' ', content)
            # 3. 去掉 HTML 残留（万一爬虫阶段没清干净）
            content = re.sub(r'<[^>]+>', '', content)
            # 4. 去掉两端空白
            content = content.strip()
            # 5. 常见噪声：正文末尾可能带上"更多"这类词
            content = re.sub(r'(更多|展开|收起)$', '', content).strip()
            df_cleaned.at[idx, '正文'] = content
        return df_cleaned

    # ==================== 标签清洗 ====================
    def clean_tags(self, df):
        """清洗标签字段，只保留图片中定义的有效类型"""
        if '标签' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx, value in df_cleaned['标签'].items():
            if pd.isna(value) or not str(value).strip():
                df_cleaned.at[idx, '标签'] = ''
                continue

            raw = str(value)
            # 统一分隔符
            for sep in ['，', '、', '；', ';', '|', '/']:
                raw = raw.replace(sep, ',')

            parts = [p.strip() for p in raw.split(',') if p.strip()]
            valid = []
            for p in parts:
                # 只保留有效标签，并且去重
                if p in self.valid_tags and p not in valid:
                    valid.append(p)

            df_cleaned.at[idx, '标签'] = ','.join(valid)
        return df_cleaned

    # ==================== URL 清洗 ====================
    def clean_url(self, df):
        """清洗 url 字段"""
        if 'url' not in df.columns:
            return df
        df_cleaned = df.copy()
        for idx, value in df_cleaned['url'].items():
            if pd.isna(value) or not str(value).strip():
                df_cleaned.at[idx, 'url'] = ''
                continue
            url = str(value).strip()
            # 只保留 http/https 开头的合法链接
            if not re.match(r'^https?://', url):
                df_cleaned.at[idx, 'url'] = ''
            else:
                df_cleaned.at[idx, 'url'] = url
        return df_cleaned

    # ==================== 缺失值处理 ====================
    def handle_missing_values(self, df):
        """处理缺失值"""
        df_cleaned = df.copy()
        # 文本类字段：空值填 '' 或 '未知'
        if '标题' in df_cleaned.columns:
            df_cleaned['标题'] = df_cleaned['标题'].fillna('无题')
        if '作者' in df_cleaned.columns:
            df_cleaned['作者'] = df_cleaned['作者'].fillna('佚名')
        if '朝代' in df_cleaned.columns:
            df_cleaned['朝代'] = df_cleaned['朝代'].fillna('未知')
        for col in ['正文', '标签', 'url']:
            if col in df_cleaned.columns:
                df_cleaned[col] = df_cleaned[col].fillna('')
        return df_cleaned

    # ==================== 数据质量报告 ====================
    def report_data_quality(self, df):
        """打印清洗前后的数据质量报告"""
        print("=" * 60)
        print("数据质量报告")
        print("=" * 60)
        total = len(df)
        if total == 0:
            print("空数据")
            return

        no_title = (df['标题'] == '').sum() if '标题' in df.columns else 0
        no_author = (df['作者'] == '佚名').sum() if '作者' in df.columns else 0
        unknown_dynasty = (df['朝代'] == '未知').sum() if '朝代' in df.columns else 0
        no_content = (df['正文'] == '').sum() if '正文' in df.columns else 0
        no_tags = (df['标签'] == '').sum() if '标签' in df.columns else 0
        no_url = (df['url'] == '').sum() if 'url' in df.columns else 0

        print(f"总条数: {total}")
        print(f"  无标题: {no_title} ({no_title / total * 100:.1f}%)")
        print(f"  佚名作者: {no_author} ({no_author / total * 100:.1f}%)")
        print(f"  未知朝代: {unknown_dynasty} ({unknown_dynasty / total * 100:.1f}%)")
        print(f"  无正文: {no_content} ({no_content / total * 100:.1f}%)")
        print(f"  无标签: {no_tags} ({no_tags / total * 100:.1f}%)")
        print(f"  无链接: {no_url} ({no_url / total * 100:.1f}%)")

        # 朝代分布
        if '朝代' in df.columns:
            print("\n朝代分布 (前10):")
            for dynasty, count in df['朝代'].value_counts().head(10).items():
                print(f"  {dynasty}: {count}")
        print("=" * 60)

    # ==================== 主流程 ====================
    def run_cleaning(self):
        print("开始古诗词数据清洗...")
        df = self.load_data()
        if df.empty:
            return pd.DataFrame()

        # 清洗前先看一眼
        print("\n清洗前数据样例：")
        for idx in range(min(3, len(df))):
            print(f"  行 {idx}: {df.at[idx, '标题']} | {df.at[idx, '作者']} | {df.at[idx, '朝代']}")

        # 逐字段清洗
        print("\n开始清洗处理...")
        df = self.clean_title(df)
        df = self.clean_author(df)
        df = self.clean_dynasty(df)
        df = self.clean_content(df)
        df = self.clean_tags(df)
        df = self.clean_url(df)
        df = self.handle_missing_values(df)

        # 删除正文为空的行（没有正文的诗词基本没用）
        before = len(df)
        df = df[df['正文'] != ''].reset_index(drop=True)
        after = len(df)
        if before != after:
            print(f"删除无正文的记录: {before - after} 条")

        # 打印质量报告
        self.report_data_quality(df)

        # 保存
        df.to_excel(self.xlsx_path, index=False)
        print(f"Excel 文件已保存至: {self.xlsx_path}")
        df.to_csv(self.csv_path, index=False, encoding='utf-8-sig')
        print(f"CSV 文件已保存至: {self.csv_path}")

        return df

if __name__ == "__main__":
    cleaner = PoetryCleaner()
    df = cleaner.run_cleaning()

"""
    对源数据进行清洗操作
    python data_processing/cleaner.py
    (在启动之前，别忘了要安装库)
"""