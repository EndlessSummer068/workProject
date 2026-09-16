# 引入第三方HTTP请求库，用于发送网络请求(如GET、POST)，从网页获取数据
import requests
# 导入BeautifulSoup库用于HTML解析，提取网页中的结构化数据
# 配合requests一起使用
from bs4 import BeautifulSoup
# 引入Pandas数据分析库，别名为pd
# 将爬取的豆瓣电影数据，转换为DataFrame格式，便于数据清洗、处理和保存为CSV/Excel文件
import pandas as pd
import time
# 引入随机数生成库
# 作用:随机选择User-Agent，降低被反爬机制识别的风险；生成随机请求间隔，模拟人类浏览行为
import random
# 引入日志记录库
import logging
# 导入Python正则表达式（Regular Expression）标准库
import re
# 从typing模块中导入类型注解
# （list列表类型，dict字典类型，any任意类型，Optional可选类型）
from typing import List, Dict, Any, Optional
# 引入os模块，提供与操作系统交互的功能
import os
# 引入sys模块，提供与Python解释器交互的功能（主要处理路径）
import sys

from tenacity import wait

# 添加项目根目录到Python模块搜索路径（确保正确导入data_processing和spiders等包，避免导入错误）
# abspath - 获取当前文件的绝对路径
# 第一次的dirname - 从完整路径中，提取目录部分（去掉文件名）
# 第二次的dirname - 在上一级，项目根目录（含项目名称）
# 注意：其实这个项目中，只需要dirname一次，也是没有问题的
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# config.py文件中有一个Config类，集中管理配置项
from config import Config

# 配置日志系统
logging.basicConfig(
    # 设置日志级别为INFO，记录INFO及以上级别日志
    level=logging.INFO,
    # 定义日志显示格式：时间 - logger名称 - 级别 - 消息内容
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
# 创建一个logger对象（用当前模块名(name)作为logger名称；区分不同模块的日志来源）
logger = logging.getLogger(__name__)

class PoetrySpider:
    """古诗词1000首爬虫"""
    def __init__(self, config: Config):
        # 接收外部传入的配置对象并存储在实例中
        self.config = config
        # 创建并存储会话对象，准备进行网络通信
        self.session = requests.Session()
        # 反爬解决方案一：请求头伪装 + 随机延迟(114行)
        # 定义HTTP请求头字典，模拟浏览器访问豆瓣
        # 伪装爬虫请求，降低被豆瓣反爬机制，识别和封禁的风险
        self.session.headers.update({
            # 浏览器->右键检查->Network->Headers->Request Headers
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
            "Accept-Encoding": "identity",
            "Connection": "keep-alive",
            "Referer": "https://www.douban.com/",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-User": "?1",
            "Cache-Control": "max-age=0",
        })

        # 添加简单的cookie
        # 给当前网络请求会话（Session），生成并添加一个随机的 Cookie（名为 bid）
        # 通常用于模拟浏览器行为、绕过网站反爬虫机制或进行自动化测试
        self.session.cookies.update({
            # 生成随机字符串
            # 从包含26个小写字母和10个数字的字符集中，随机抽取11个字符
            # 通过join拼接成一个完整的、没有间隔的字符串
            'bid': ''.join(random.choices('abcdefghijklmnopqrstuvwxyz0123456789', k=11)),
        })
        # 从config模块加载豆瓣配置信息到实例变量
        self.poetry_config = config.POETRY_CONFIG
        # 最大重试次数为3次
        # （用于网络请求失败时自动重试机制，提高爬虫稳定性）
        self.max_retries = 3

    # 该方法，接收起始位置start参数（默认0）
    # 该方法，返回类型为字典列表，每个字典包含电影信息
    def get_page_data(self, page: int = 1) -> List[Dict[str, Any]]:
        """
        获取单页电影数据
        :param page: 页码，从 1 开始(第 1 页对应网站首页)
        """

        # ----- 1. 拼接 URL -----
        # 从配置中获取基础URL
        # 古诗词网的第 1 页是首页，没有 index_1
        # 第 2 页开始是 /index_2、/index_3...
        base_url = self.poetry_config['base_url'].rstrip('/')
        url = f"{base_url}/" if page == 1 else f"{base_url}/index_{page}"

        poems = []

        # ----- 2. 重试循环 -----
        for attempt in range(self.max_retries):
            try:
                logger.info(f"正在爬取第{page}页，(尝试{attempt + 1}/{self.max_retries})")
                # 模拟人类行为，避免请求频率过高被封禁
                # 生成3到6秒之间的随机浮点数
                time.sleep(random.uniform(3, 6))
                # 发送http get请求
                # 用session对象获取URL内容
                # 设置超时时间防止无限等待
                # 允许重定向处理URL跳转
                response = self.session.get(
                    url,
                    timeout=self.poetry_config['timeout'],
                    allow_redirects = True
                )

                # ----- 3. 状态码和内容长度检查 -----
                if response.status_code != 200:
                    # 记录警告日志
                    logger.warning(f"HTTP状态码异常: {response.status_code}")
                    # 状态码非200，放弃本次解析，进入下一次重试
                    continue
                if not response.text or len(response.text) < 1000:
                    logger.warning("响应内容异常")
                    continue

                # ----- 4. 解析HTML -----
                soup = BeautifulSoup(response.text, 'html.parser')

                # 古诗词网每条诗是一个 <li class="gushici-box">
                poem_items = soup.find_all("li", class_="gushici-box")
                if not poem_items:
                    logger.warning("未找到诗词条目")
                    continue

                # ----- 5. 逐条提取数据 -----
                for item in poem_items:
                    poem = self._parse_poem_item(item)
                    if poem:
                        poems.append(poem)

                if poems:
                    logger.info(f"第{page}页爬取完成，获取{len(poems)}首诗词")
                    break
                else:
                    logger.warning(f"第{page}页解析到0首诗词")

            except requests.exceptions.Timeout:
                logger.warning(f"请求超时，第{attempt + 1}次尝试")
            except requests.exceptions.ConnectionError:
                logger.warning(f"连接错误，第{attempt + 1}次尝试")
            except Exception as e:
                logger.error(f"获取第{page}页数据失败: {e}")

            # ----- 6. 等待重试 -----
            if attempt < self.max_retries - 1:
                wait_time = random.uniform(8, 15)
                logger.info(f"等待{wait_time:.1f}秒后重试...")
                time.sleep(wait_time)

        return poems

    # 私有方法（下划线前缀）
    # 解析单个古诗词，参数：item - 单古诗词项
    # 返回类型为可选字典，包含诗词信息或None
    # 从单个诗词HTML元素中提取标题、作者、朝代等数据
    def _parse_poem_item(self, item) -> Optional[Dict[str, Any]]:
        """解析单个诗词项"""
        try:
            # 基础诗词数据结构
            poem_data = {
                '标题':'',
                '作者':'',
                '朝代': '',
                '正文': '',
                '标签': [],
                'url':''
            }

            # 1. 提取标题
            title_elem = item.find("h3", class_="title")
            if title_elem:
                # 获取标签内的纯文本，去除所有HTML标记
                poem_data['标题'] = title_elem.text.strip()

            # 2. 提取作者
            author_elem = item.find("a", class_="author")
            if author_elem:
                poem_data['作者'] = author_elem.text.strip()

            # 3. 提取朝代
            dynasty_elem = item.find("a", class_="dynasty")
            if dynasty_elem:
                poem_data['朝代'] = dynasty_elem.get_text(strip=True).strip('〔〕')

            # 4. 提取正文
            content_elem = item.find("div", class_="contson")
            if content_elem:
                for br in content_elem.find_all("br"):
                    br.replace_with(' ')
                poem_data['正文'] = content_elem.text.strip()

            # 5. 提取url
            if title_elem:
                url_elem = title_elem.find("a")
                if url_elem and url_elem['href']:
                    poem_data['url'] = url_elem['href']

            # 6. 提取标签
            tag_elem = item.find("div", class_="tag")
            if tag_elem:
                tags =[]
                for tag in tag_elem.find_all("a"):
                    tag_name = tag.text.strip()
                    if tag_name:
                        tags.append(tag_name)
                poem_data['标签'] = tags

            return poem_data

        except Exception as e:
            logger.warning(f"解析诗词条目失败: {e}")
            return None



    def crawl_all_poems(self, max_pages: int = None) -> pd.DataFrame:
        """---爬取古诗词网所有诗词---"""
        if max_pages is None:
            max_pages = self.poetry_config['max_pages']
        logger.info(f"开始爬取古诗词网，最多{max_pages}页...")

        all_poems = []
        for page in range(1, max_pages + 1):
            poems = self.get_page_data(page)
            all_poems.extend(poems)

            # 如果某页数据不足 10 首，可能已到末尾
            if len(poems) < 10 and page < max_pages:
                logger.warning(f"第{page}页只获取到{len(poems)}首，可能已到末尾")
            # 该页 0 首 → 大概率已到末尾，提前结束
            if len(poems) == 0:
                logger.warning(f"第{page}页获取到0首，可能已到末尾，提前结束")
                break

            logger.info(f"进度: {page}/{max_pages}页，已获取{len(all_poems)}首诗词")

            # 当前页成功获取到数据 & 不是最后一页
            if len(poems) > 0 and page < max_pages:
                # 3-6秒随机延迟 - 避免频繁请求触发反爬机制
                time.sleep(random.uniform(3, 6))

        df = pd.DataFrame(all_poems)

        # 确保有数据才处理
        if not df.empty:

            # 标签列表 -> 逗号分隔字符串
            if '标签' in df.columns:
                df['标签'] = df['标签'].apply(
                    lambda tags: ','.join(tags) if isinstance(tags, list) else ''
                )

            # 定义期望的列名顺序列表
            columns_order = ['标题','作者','朝代','正文','标签','url']
            existing_columns = [col for col in columns_order if col in df.columns]
            # df[existing_columns]:按指定顺序（重排）选取存在的列
            # df = ...:将结果赋值回原变量
            df = df[existing_columns]

            # 保存原始数据，将DataFrame保存为CSV文件
            # self.config.Poetry_CSV_PATH:csv文件保存路径
            # index=False:不写入行索引
            # 为什么要特意用utf-8-sig而不是普通的utf-8？
            # 用Excel保存CSV文件，Excel默认会在文件开头，偷偷塞入一个不可见的BOM头（\xef\xbb\xbf）
            # 普通utf-8读取，会把BOM头当成第一列列名的一部分，导致第一列名字看起来像'\ufeff姓名'，后续处理非常容易报错
            # 用utf-8-sig读取，会自动识别并忽略掉这个BOM头，完美拿到真实列名
            df.to_csv(self.config.POETRY_CSV_PATH, index=False, encoding='utf-8-sig')
            # 同时保存为文本格式
            self._save_as_text(df)
            logger.info(f"共爬取{len(df)}首诗词，已保存到{self.config.POETRY_CSV_PATH}")

            # 数据质量检查
            no_title = (df['标题'] == '').sum()
            no_author = (df['作者'] == '').sum()
            no_content = (df['正文'] == '').sum()
            logger.info(
                f"数据质量: 无标题{no_title}首, 无作者{no_author}首, 无正文{no_content}首"
            )
            # 数量预警（古诗词网每页 10 首）
            expected = max_pages * 10
            if len(df) < expected * 0.9:
                logger.warning(f"期望约{expected}首，实际只有{len(df)}首，请检查是否被反爬")
        else:
            logger.warning("未爬取到任何诗词")
        return df

    def _save_as_text(self, df: pd.DataFrame):
        """保存为文本格式"""
        try:
            with open(self.config.POETRY_TEXT_PATH, 'w', encoding='utf-8') as f:
                f.write('古诗词网 诗词集\n')
                # "=" * 60:生成60个等号，作为装饰分隔线
                f.write("=" * 60 + "\n\n")

                # 逐行输出诗词信息
                # iterrows():返回迭代器，每次产生(索引，行数据)元组
                for idx, row in df.iterrows():
                    # 如 "1. 静夜思"
                    f.write(f"{idx + 1}. {row['标题']}\n")

                    # 作者 + 朝代合并输出，例如 "   作者: 李白 〔唐代〕"
                    author = row.get('作者', '')
                    dynasty = row.get('朝代', '')
                    if pd.notna(author) and author:
                        if pd.notna(dynasty) and dynasty:
                            f.write(f"   作者: {author} 〔{dynasty}〕\n")
                        else:
                            f.write(f"   作者: {author}\n")

                    # 正文（古诗词一般很短，不用截断）
                    content = row.get('正文', '')
                    if pd.notna(content) and content:
                        f.write(f"   正文: {content}\n")
                    else:
                        f.write(f"   正文: (无正文)\n")

                    # 标签（用 | 分隔，和豆瓣的 info_parts 风格保持一致）
                    tags = row.get('标签', '')
                    if pd.notna(tags) and tags:
                        # 若存的是列表就 join；若是字符串直接替换分隔
                        if isinstance(tags, list):
                            tags_str = ' | '.join(tags)
                        else:
                            tags_str = tags.replace(',', ' | ')
                        f.write(f"   标签: {tags_str}\n")

                    # 详情页 URL
                    url = row.get('url', '')
                    if pd.notna(url) and url:
                        f.write(f"   链接: {url}\n")

                    f.write("-" * 50 + "\n\n")

                logger.info(f"文本数据已保存到{self.config.POETRY_TEXT_PATH}")

        except Exception as e:
            logger.error(f"保存文本数据失败: {e}")

    # df:pd.DataFrame: 待验证的数据框
    # 返回字典类型
    def validate_data(self, df: pd.DataFrame) -> Dict[str, Any]:
        # 初始化验证结果字典
        validation_result = {
            'total_poetry': len(df),  # 诗词总数
            'columns': list(df.columns),  # 所有列名列表（# 这里的[Any] 是自动补充所产生的类型提示，不是必须的）
            'missing_data': {},  # 空字典，后续填充各列缺失值统计
            'data_quality': {}  # 空字典，后续填充数据质量指标
        }
        # 检查缺失值
        # 遍历DataFrame的所有列名
        # 检查缺失值（所有列通用，逐个统计）
        for column in df.columns:
            # 字符串列可能被存成空串 '' 而不是 NaN，
            # 所以这里同时统计 NaN 和空串两种情况
            missing_count = df[column].isnull().sum()
            if df[column].dtype == object:
                empty_count = (df[column] == '').sum()
                missing_count += empty_count
            validation_result['missing_data'][column] = {
                'missing_count': int(missing_count),
                # 缺失占比，保留 2 位小数
                'missing_percentage': round(missing_count / len(df) * 100, 2)
            }
            # 多维度数据质量检查
            # 为什么只有评分字段，需要做多维度数据校验，其他字段，直接判断是否有缺失值即可？
            # 评分是数值型，数值型可以进行数学运算（max,min,mean）
            # 其他字段基本上都是字符串类型
            # 多维度数据质量检查
            # 古诗词没有数值型字段，所以重点看"是否至少有一条有效数据"
            validation_result['data_quality'] = {
                # 是否至少有一首诗有标题
                'has_titles': not df['标题'].isnull().all() if '标题' in df.columns else False,
                # 是否至少有一首诗有作者
                'has_author_info': df['作者'].notna().sum() if '作者' in df.columns else 0,
                # 是否至少有一首诗有朝代
                'has_dynasty_info': df['朝代'].notna().sum() if '朝代' in df.columns else 0,
                # 有正文的数量（最关键的一列）
                'has_content': df['正文'].notna().sum() if '正文' in df.columns else 0,
                # 有标签的数量
                'has_tags': (df['标签'] != '').sum() if '标签' in df.columns else 0,
                # 有详情页链接的数量
                'has_url': df['url'].notna().sum() if 'url' in df.columns else 0,
                # 正文平均长度（用来看解析是否把该抓的文字都抓到了）
                'avg_content_length': round(df['正文'].str.len().mean(), 1) if '正文' in df.columns else 0,
            }
        return validation_result


# 爬虫要调试，是因为网络请求和HTML解析容易出错，调试能快速定位问题
def debug_single_page():
    """调试单页数据"""
    config = Config()
    spider = PoetrySpider(config)
    # 只爬取第一页用于调试
    poems = spider.get_page_data(1)  # 古诗词网第 1 页传 1（不再是索引 0）
    if poems:
        print(f"\n获取到{len(poems)}首诗词:")

        # 显示有正文和无正文的
        with_content = [p for p in poems if p['正文']]
        without_content = [p for p in poems if not p['正文']]
        print(f"有正文的诗词: {len(with_content)} 首")
        print(f"无正文的诗词: {len(without_content)} 首")

        print("\n前5首诗词完整信息:")
        for i, poem in enumerate(poems[:5]):
            print(f"\n第 {i + 1} 首诗词:")
            for key, value in poem.items():
                print(f"   {key}: {value}")

        # 保存调试数据
        df = pd.DataFrame(poems)
        # 标签列表 -> 逗号字符串，方便查看
        if '标签' in df.columns:
            df['标签'] = df['标签'].apply(
                lambda t: ','.join(t) if isinstance(t, list) else ''
            )
        debug_path = "debug_poems.csv"
        df.to_csv(debug_path, index=False, encoding='utf-8-sig')
        print(f"\n调试数据已保存到: {debug_path}")
    else:
        print("未获取到诗词数据")

if __name__ == "__main__":
    # 调试模式: python spiders/poetry_spider.py debug
    if len(sys.argv) > 1 and sys.argv[1] == "debug":
        debug_single_page()
    else:  # 非调试模式: python spiders/spider.py
        config = Config()
        spider = PoetrySpider(config)
        # 爬取所有诗词
        df = spider.crawl_all_poems()

        if not df.empty:
            print(f"\n爬取完成！共获取{len(df)}首诗词")
            print(f"数据已保存到: {config.POETRY_CSV_PATH}")
            print(f"文本格式已保存到: {config.POETRY_TEXT_PATH}")

            # 显示正文提取情况（对应豆瓣的"有简介"）
            content_count = (df['正文'] != '').sum()
            print(f"正文提取情况: {content_count}/{len(df)} 首有正文")

            # 显示标签提取情况
            if '标签' in df.columns:
                tagged = (df['标签'] != '').sum()
                print(f"标签提取情况: {tagged}/{len(df)} 首有标签")

            # 显示前5首诗词用于验证解析是否正确
            print("\n前5首诗词数据（用于验证解析是否正确）:")
            for i, row in df.head(5).iterrows():
                print(f"\n{i + 1}. {row['标题']}")
                print(f"   作者: {row.get('作者', '')}  〔{row.get('朝代', '')}〕")
                print(f"   正文: {row.get('正文', '')}")
                print(f"   标签: {row.get('标签', '')}")
                print(f"   链接: {row.get('url', '')}")
        else:
            print("爬取失败，未获取到数据")
