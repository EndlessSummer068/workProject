# 整个项目的工作流是分阶段进行的：
#   爬取数据    →    清洗数据     →     分析数据     →     Web展示
# (spider.py)     (cleaner.py)       (analyzer.py)    (app.py)

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


class DoubanMovieSpider:
    """豆瓣电影Top250爬虫"""
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
        self.douban_config = config.DOUBAN_CONFIG
        # 最大重试次数为3次
        # （用于网络请求失败时自动重试机制，提高爬虫稳定性）
        self.max_retries = 3

    # 该方法，接收起始位置start参数（默认0）
    # 该方法，返回类型为字典列表，每个字典包含电影信息
    def get_page_data(self, start: int = 0) -> List[Dict[str, Any]]:
        """获取单页电影数据"""
        # 从配置中获取基础URL
        # 用f-string将起始位置start参数拼接到URL中
        # （例如：https://api.douban.com/v2/movie/top250?start=0）
        url = f"{self.douban_config['base_url']}?start={start}"
        movies = []

        # max_retries为最大重试次数
        for attempt in range(self.max_retries):
            try:
                # 计算当前页码（start//25 + 1，每页25条数据）
                # 显示当前重试次数和最大重试次数
                # 用f-string格式化输出
                logger.info(f"正在爬取第{start // 25 + 1}页 (尝试{attempt + 1}/{self.max_retries})")
                # 模拟人类行为，避免请求频率过高被封禁
                # 生成3到6秒之间的随机浮点数
                time.sleep(random.uniform(3, 6))
                # 发送http get请求
                # 用session对象获取URL内容
                # 设置超时时间防止无限等待
                # 允许重定向处理URL跳转
                response = self.session.get(
                    url,
                    timeout=self.douban_config['timeout'],
                    allow_redirects=True,
                )
                # 发送http请求后，响应的状态码是否为200
                if response.status_code != 200:
                    # 记录警告日志
                    logger.warning(f"HTTP状态码异常: {response.status_code}")
                    # 状态码非200，放弃本次解析，进入下一次重试
                    continue
                # 检查响应内容长度是否合理
                if not response.text or len(response.text) < 1000:
                    logger.warning("响应内容异常")
                    # 状态码非200，放弃本次解析，进入下一次重试
                    continue
                # 使用BeautifulSoup解析HTML（页面是用html结构写的）
                # .text 获取HTTP响应的HTML文本内容
                # html.parser -- 使用Python内置的HTML解析器
                soup = BeautifulSoup(response.text, "html.parser")
                # 查找所有class为"item"的div元素（电影条目）
                movie_items = soup.find_all("div", class_="item")
                if not movie_items:
                    logger.warning("未找到电影条目")
                    # 当BeautifulSoup解析页面后发现没有任何电影条目时，跳过本次解析，进入下一次重试
                    continue
                # 解析电影数据
                for item in movie_items:
                    # 逐个处理电影项，用_parse_movie_item方法提取信息
                    movie = self._parse_movie_item(item)
                    # 成功解析则添加到列表
                    if movie:
                        movies.append(movie)
                # 如果获取到数据，则记录日志，并跳出重试循环
                if movies:
                    # start - - 当前爬取的起始位置（索引）（0，25，50，...）
                    # //25 -- 计算当前页码（整除25(每页25部电影)）
                    # + 1 -- 显示当前页码（转为从1开始的实际页码）
                    logger.info(f"第{start // 25 + 1}页爬取完成，获取{len(movies)}部电影")
                    break
                else:
                    # 记录警告继续重试
                    logger.warning(f"第{start // 25 + 1}页解析到0部电影")
            except requests.exceptions.Timeout:
                logger.warning(f"请求超时，第{attempt + 1}次尝试")
            except requests.exceptions.ConnectionError:
                logger.warning(f"连接错误，第{attempt + 1}次尝试")
            except Exception as e:
                logger.error(f"获取第{start // 25 + 1}页数据失败: {e}")

            # 重试等待机制
            # （请求失败时，增加较长延时后重试，避免频繁请求被封）
            # 判断是否还有重试机会
            if attempt < self.max_retries - 1:
                # 生成8到15秒的随机等待时间
                # （正常爬取情况下，每次请求之间的时间间隔）
                wait_time = random.uniform(8, 15)
                # 记录等待日志并暂停执行
                # f表示浮点数，.1f表示保留一位小数
                logger.info(f"等待{wait_time:.1f}秒后重试...")
                time.sleep(wait_time)
        return movies

    # 私有方法（下划线前缀）
    # 解析单个电影，参数：item - 单个电影项
    # 返回类型为可选字典，包含电影信息或None
    # 从单个电影HTML元素中提取标题、导演、评分等数据
    def _parse_movie_item(self, item) -> Optional[Dict[str, Any]]:
        """解析单个电影项"""
        try:
            # 基础电影数据结构 - 导演和演员分开
            movie_data = {
                '电影名': '',
                '别名': '',
                '导演': '',  # 导演
                '演员': '',  # 演员
                '上映年份': '',
                '国家地区': '',
                '电影类型': '',
                '评分': 0.0,
                '评价人数': 0,
                '简介': ''  # 一句话简介
            }

            # 1. 提取电影标题（主标题）
            title_elem = item.find("span", class_="title")
            if title_elem:
                # 获取标签内的纯文本，去除所有HTML标记
                movie_data['电影名'] = title_elem.text.strip()

            # 2. 提取别名信息
            other_titles = []
            # 英文标题
            # lang='en-US':指定语言区域参数（en-英语，US-美国地区）
            english_title_elem = item.find("span", class_="title", lang="en-US")
            if english_title_elem:
                english_title = english_title_elem.text.strip()
                other_titles.append(english_title)
            # 其他别名
            # find_all:搜索并返回，所有匹配条件的，HTML元素列表
            other_elems = item.find("span", class_="other")
            for elem in other_elems:
                text = elem.text.strip()
                if text:
                    # 查找变量text中，位于开头或结尾，的所有空白字符
                    # 将找到的这些空白字符，替换为空字符串
                    # 将处理后的新字符串，重新赋值给text变量
                    text = re.sub(r'^[/\s]+|[/\s]+$', "", text)
                    if text:
                        other_titles.append(text)
            # 合并所有别名
            if other_titles:
                # 将多个别名用斜杠连接成字符串
                # " / ".join():用"/"作为分隔符，将列表元素拼接为单个字符串
                # （如：'a','b'  结果 'a / b'）
                movie_data['别名'] = '/'.join(other_titles)

            # 3. 提取简介（一句话描述）- 修复版
            # 豆瓣Top250中，简介通常在class="quote"的p标签内的span中
            # 避免获取页面无关的文本（例如：<div class="quote">...</div>就不会被匹配到）
            quote_elem = item.find('p', class_="quote")
            if quote_elem:
                span_elem = quote_elem.find("span")
                if span_elem:
                    movie_data['简介'] = span_elem.text.strip()
                    logger.debug(f"找到简介: {movie_data['简介']}")

            # 4. 提取评分信息
            rating_elem = item.find("span", class_="rating_num")
            if rating_elem:
                try:
                    rating_text = rating_elem.text.strip()
                    # 匹配一个或多个数字或小数点
                    # （
                    # [\d.]意思是：匹配一个数字或者一个点
                    # + 匹配一次或多次
                    # 在变量rating_text中去匹配，搜索第一个符合“由数字或点组成”的模式
                    # 如果找到匹配项，返回一个Match对象，并将其赋值给变量rating_match
                    # 如果没有找到匹配项，则返回None
                    # ）
                    rating_match = re.search(r"[\d.]+", rating_text)
                    if rating_match:
                        # group() -- 提取匹配的文本内容
                        # 将字符串转换成浮点数类型
                        movie_data['评分'] = float(rating_match.group())
                except:
                    pass

            # 5. 提取评价人数
            rating_count = 0
            # 优化后的方案：直接在item范围内查找包含"人评价"的span标签
            # 根据新的HTML结构，<span>300861人评价</span>现在直接作为.item的子元素
            try:
                # 查找所有span标签，遍历找到包含"人评价"的那个
                all_spans = item.find_all('span')
                for span in all_spans:
                    span_text = span.text.strip()
                    if "人评价" in span_text:
                        # 将"人评价"替换为空字符串，只要纯数字
                        count_text = span_text.replace('人评价', '').strip()
                        rating_count = self._parse_rating_count(count_text)
                        break
            except Exception as e:
                logger.warning(f"提取评价人数时出错: {e}")

            if rating_count == 0:
                # 提取标签内的纯文本内容
                all_text = item.get_text()
                # 提取评价人数的数值部分，支持"万"单位
                # [\d.]+ 匹配整数或小数一次或多次
                # 万? 匹配汉字“万” 以及 前面的字符（“万”）出现0次或1次
                # \s* 匹配任意空白字符，出现0次或多次
                rating_match = re.search(r'([\d.]+万?)\s*人评价', all_text)
                if rating_match:
                    # 例如："123.4万人评价"
                    # group(0)结果是"123.4万人评价"  group(1)结果是"123.4万" -- 表示第一个捕获组
                    rating_count = self._parse_rating_count(rating_match.group(1))
            movie_data['评价人数'] = rating_count

            # 6. 提取电影详细信息（导演、演员、年份、国家、类型）
            self._parse_movie_info(item, movie_data)
            # 检查电影名字段，是否为空或None
            if not movie_data['电影名']:
                # 记录警告日志
                logger.warning("电影名提取失败")
                # 无有效数据
                return None
            return movie_data
        except Exception as e:
            logger.error(f"解析电影项失败: {e}")
            return None

    # Dict[str,Any]为movie_data参数是字典类型，键为字符串，值为任意类型
    def _parse_movie_info(self, item, movie_data: Dict[str, Any]):
        """解析电影详细信息 - 导演和演员分开"""
        try:
            # 查找包含电影信息的div
            bd_elem = item.find("div", class_="bd")
            if not bd_elem:
                # 隐式返回None
                return
            # 查找所有p标签
            p_elems = bd_elem.find_all("p")
            if not p_elems:
                return
            # 第一个p标签通常包含导演、演员信息
            if len(p_elems) > 0:
                # [0]是列表索引，获取第一个元素
                # 为什么用 [0]
                #   find_all()返回列表，即使只有一个元素也是列表格式
                #   [0]提取第一个<p>标签对象，用于后续解析导演、演员等信息
                first_p = p_elems[0]
                # 从第一个<p>标签中，提取纯文本并去除空白
                # strip=True:自动去除首尾空格、换行符等空白字符
                info_text = first_p.get_text(strip=True)
                # 提取导演信息（例如：导演：张三 zhangsan 主演：李四 中 提取 张三 zhangsan）
                # \s* 匹配前导空白
                # (.+?) 非贪婪捕获任意字符
                # (?=\s*主演:|$) 遇到"主演:"或字符串结尾时停止
                director_match = re.search(r'导演:\s*(.+?)(?=\s*主演:|$)', info_text)
                if director_match:
                    # group(0) -- 导演：张三 zhangsan
                    # group(1) -- 张三 zhangsan
                    director_str = director_match.group(1).strip()
                    # 清理导演名字中的多余空白字符（将多个空格替换成一个空格）
                    # sub() -- 正则的替换函数
                    # r'\s+': 匹配一个或多个连续空白
                    # ' ' 替换为单个空格
                    director_str = re.sub(r'\s+', ' ', director_str)
                    movie_data['导演'] = director_str

                # 从文本中提取演员信息（例如：主演：张三 zhangsan /... 2026 中提取演员列表，不包括年份）
                # \s* 匹配前导空白
                # (.+?) 非贪婪捕获任意字符
                # (?=\s*\d{4}|$) 遇到年份(4位数字)或行尾时停止
                actor_match = re.search(r'主演:\s*(.+?)(?=\s*\d{4}|$)', info_text)
                if not actor_match:
                    # 如果上一个正则匹配失败时，用此简化版本正则兜底（提取'主演:'后的全部内容，适用于没有年份的）
                    # \s* 匹配前导空白
                    # (.+) 贪婪捕获剩余所有非换行字符
                    actor_match = re.search(r'主演:\s*(.+)', info_text)

                if actor_match:
                    # 提取正则表达式中第一个捕获组的演员信息
                    # group(1):获取第一个括号(.+)或(.+?)捕获的内容
                    # （例如：主演：张三 zhangsan /...  不包含'主演:'前缀）
                    actor_str = actor_match.group(1).strip()
                    # 清理演员名字中的多余空格
                    actor_str = re.sub(r'\s+', ' ', actor_str)
                    movie_data['演员'] = actor_str

                # 提取年份、国家、类型信息
                # 查找数字年份（4位数字）
                # \b 单词边界，确保独立匹配
                # (19|20) 匹配19或20开头
                # \d{2} 匹配任意两位数字
                # 整个正则表示：匹配1900-2099年之间的年份
                year_match = re.search(r'\b(19|20)\d{2}\b', info_text)
                if year_match:
                    # 获取匹配结果，在原文本中的起始位置索引
                    # start() 是正则表达式匹配对象的方法，用于获取匹配结果的起始索引
                    # 如：'导演:李四 2018/美国/剧情'，若2018从索引6开始，则返回6
                    year_start = year_match.start()
                    # 从year_start索引位置开始，截取到字符串末尾
                    # 例如从"导演:xxx 1994/美国/剧情"中提取"1994/美国/剧情"
                    year_info = info_text[year_start:]
                    # part（第一个） -- 是列表推导式的输出表达式，是对每个元素处理后的结果
                    parts = [part.strip() for part in year_info.split('/')]
                    if len(parts) >= 1:
                        # 用索引获取列表中的数据
                        movie_data['上映年份'] = parts[0]
                    if len(parts) >= 2:
                        movie_data['国家地区'] = parts[1]
                    if len(parts) >= 3:
                        movie_data['电影类型'] = parts[2]
                # 正则匹配失败后的备选分支
                # 判断字符串中含有'/'，则尝试用'/'分割字符串，并获取年份、国家、类型信息
                elif '/' in info_text:
                    # all_parts = ["导演: xxx 1994","美国","剧情"]
                    all_parts = [part.strip() for part in info_text.split('/')]
                    # 遍历列表并获取索引和元素
                    # enumerate()函数，用于同时获取索引和元素值
                    # 这里的[Any] 是自动补充所产生的类型提示，不是必须的
                    for i, part in enumerate(all_parts):
                        # \d{4} 匹配恰好4个数字
                        # 验证年份，确保字符串，仅包含4位数字
                        if re.match(r'\d{4}$', part):
                            movie_data['上映年份'] = part
                            # 防止列表索引越界
                            if i + 1 < len(all_parts):
                                movie_data['国家地区'] = all_parts[i + 1]
                            if i + 2 < len(all_parts):
                                movie_data['电影类型'] = all_parts[i + 2]
                            break
        except Exception as e:
            logger.warning(f"解析电影详细信息失败: {e}")

    # rating_count_str: str  字符串类型的评价人数文本
    # 返回整数
    def _parse_rating_count(self, rating_count_str: str) -> int:
        """解析评价人数"""
        # 判断字符串是否为空
        if not rating_count_str:
            return 0
        try:
            # 两个replace是为了，同时处理英文逗号和中文逗号（兼容性）
            # '1，234万' --> '1234万'
            rating_count_str = rating_count_str.strip().replace(',', '').replace('，', '')
            # 检查字符串中是否有"万"字
            if '万' in rating_count_str:
                # 匹配数字和小数点,提取纯数值部分
                number_match = re.search(r'[\d.]+', rating_count_str)
                # 成功匹配到数字
                if number_match:
                    # 提取并转换为浮点数
                    # group()不带参数时，默认等同于group(0)，表示整个匹配的文本
                    number = float(number_match.group())
                    # 将"万"单位还原为实际人数
                    return int(number * 10000)
                else:
                    return 0
            else:
                # 提取整数部分，与带"万"单位分支形成互补
                # r'\d+':匹配一个或多个连续数字
                number_match = re.search(r'\d+', rating_count_str)
                if number_match:
                    return int(number_match.group())
                else:
                    return 0
        except Exception as e:
            logger.warning(f"解析评价人数失败: {rating_count_str}, 错误: {e}")
            return 0

    # 爬取全部电影
    # max_pages:int = None:可选参数，指定最大爬取页数(默认无限制)
    # （int=None 不表示没有长度限制，而是表示参数可选，默认值为None）
    # （None表示用户未指定，0容易被误认为爬取0页）
    # 返回DataFrame对象
    def crawl_all_movies(self, max_pages:int=None) -> pd.DataFrame:
        """爬取所有电影数据"""
        # 如果参数是默认值
        if max_pages is None:
            # 则使用实际值
            max_pages = self.douban_config['max_pages']
        logger.info(f"开始爬取豆瓣电影Top250，最多{max_pages}页...")

        all_movies = []
        for i in range(max_pages):
            # 每页25条数据，计算当前页起始索引
            # （i=0，start=0；i=1，start=25；i=2，start=50，。。。）
            start = i * 25
            movies = self.get_page_data(start)
            all_movies.extend(movies)
            # 当前页数据不足25条 & 未达到预设的最大页数
            if len(movies) < 25 and i < max_pages - 1:
                logger.warning(f"第{i + 1}页只获取到{len(movies)}部电影，可能已到末尾")
                break
            logger.info(f"进度: {i + 1}/{max_pages}页，已获取{len(all_movies)}部电影")
            # 当前页成功获取到数据 & 不是最后一页
            if len(movies) >0 and i < max_pages - 1:
                # 3-6秒随机延迟 - 避免频繁请求触发反爬机制
                delay = random.uniform(3, 6)
                time.sleep(delay)

        # 转换为DataFrame
        df = pd.DataFrame(all_movies)
        # 确保有数据才处理
        if not df.empty:
            # 定义期望的列名顺序列表
            columns_order = ['电影名', '别名', '导演', '演员', '上映年份', '国家地区', '电影类型',
                             '评分', '评价人数', '简介']
            # 先执行for...in，然后执行if...in，最后再用第一个col显示
            existing_columns = [col for col in columns_order if col in df.columns]
            # df[existing_columns]:按指定顺序（重排）选取存在的列
            # df = ...:将结果赋值回原变量
            df = df[existing_columns]
            # 保存原始数据
            # 将DataFrame保存为CSV文件
            # self.config.DOUBAN_MOVIE_PATH:csv文件保存路径
            # index=False:不写入行索引

            # 为什么要特意用utf-8-sig而不是普通的utf-8？
            # 用Excel保存CSV文件，Excel默认会在文件开头，偷偷塞入一个不可见的BOM头（\xef\xbb\xbf）
            # 普通utf-8读取，会把BOM头当成第一列列名的一部分，导致第一列名字看起来像'\ufeff姓名'，后续处理非常容易报错
            # 用utf-8-sig读取，会自动识别并忽略掉这个BOM头，完美拿到真实列名
            df.to_csv(self.config.DOUBAN_MOVIE_PATH, index=False)
            # 同时保存为文本格式
            self._save_as_text(df)
            logger.info(f"共爬取{len(df)}部电影，已保存到{self.config.DOUBAN_MOVIE_PATH}")

            # 验证数据质量
            # 确保爬取的数据可靠（缺失值，评分范围，年份合法性）
            # 目的：验证后，发现异常，说明爬虫解析失败，要修复代码，重新爬取，而不是爬到错误数据进行后续分析
            validation = self.validate_data(df)
            # 逗号是千位分隔符，例如：5,000,000
            logger.info(
                f"数据质量报告: 平均评分{validation['data_quality']['avg_rating']:.2f}, 总评价人数{validation['data_quality']['total_ratings']:,}")
            # df['简介'] -- 选取简介列
            # notna() -- 判断是否是空（True计为1，False计为0）
            # 例如250部电影中，有230部有简介，结果为230
            summary_with_intro = df['简介'].notna().sum()
            logger.info(f"简介提取情况: {summary_with_intro}/{len(df)} 部电影有简介")
        else:
            logger.warning("未爬取到任何电影数据")
        return df

    # 将爬取的电影数据，格式化为可读的TXT文件
    def _save_as_text(self, df: pd.DataFrame):
        """保存为文本格式"""
        try:
            with open(self.config.DOUBAN_TEXT_PATH, 'w', encoding='utf-8') as f:
                f.write('豆瓣电影Top250\n')
                # "=" * 60:生成60个等号，作为装饰分隔线
                f.write("=" * 60 + "\n\n")
                # 逐行输出电影信息
                # iterrows():返回迭代器，每次产生(索引，行数据)元组
                for idx, row in df.iterrows():
                    # 如 "1. 肖申克的救赎"
                    f.write(f"{idx + 1}. {row['电影名']}\n")
                    # 判断别名是否有缺失值 且 是否为非空字符串（避免输出 别名： ）
                    if pd.notna(row.get('别名')) and row['别名']:
                        f.write(f"   别名: {row['别名']}\n")
                    f.write(f"   评分: {row['评分']} ⭐ | 评价人数: {row['评价人数']:,}\n")

                    if pd.notna(row.get('导演')) and row['导演']:
                        f.write(f"   导演: {row['导演']}\n")
                    if pd.notna(row.get('演员')) and row['演员']:
                        # 获取该行"演员"列的值，存储到变量
                        actors = row['演员']
                        # 如果演员列表太长，截取一部分
                        if len(actors) > 100:
                            # 加省略号
                            actors = actors[:100] + "..."
                        f.write(f"   演员: {actors}\n")
                    info_parts = []
                    if pd.notna(row.get('上映年份')) and row['上映年份']:
                        info_parts.append(f"上映年份: {row['上映年份']}")
                    if pd.notna(row.get('国家地区')) and row['国家地区']:
                        info_parts.append(f"国家地区: {row['国家地区']}")
                    if pd.notna(row.get('电影类型')) and row['电影类型']:
                        info_parts.append(f"类型: {row['电影类型']}")
                    if info_parts:
                        f.write(f"   信息: {' | '.join(info_parts)}\n")
                    if pd.notna(row.get('简介')) and row['简介']:
                        f.write(f"   简介: {row['简介']}\n")
                    else:
                        # 输出空简介
                        f.write(f"   简介: (无简介)\n")
                    f.write("-" * 50 + "\n\n")
                logger.info(f"文本数据已保存到{self.config.DOUBAN_TEXT_PATH}")
        except Exception as e:
            logger.error(f"保存文本数据失败: {e}")

    # df:pd.DataFrame: 待验证的数据框
    # 返回字典类型
    def validate_data(self, df: pd.DataFrame) -> Dict[str, Any]:
        # 初始化验证结果字典
        validation_result = {
            'total_movies': len(df),  # 电影总数
            'columns': list(df.columns),  # 所有列名列表（# 这里的[Any] 是自动补充所产生的类型提示，不是必须的）
            'missing_data': {},  # 空字典，后续填充各列缺失值统计
            'data_quality': {}  # 空字典，后续填充数据质量指标
        }
        # 检查缺失值
        # 遍历DataFrame的所有列名
        for column in df.columns:
            # 计算该列空值数量
            missing_count = df[column].isnull().sum()
            # 将缺失值结果存入missing_data字典
            # [column]以列名为键，例如 ['missing_data']['导演']
            validation_result['missing_data'][column] = {
                'missing_count': missing_count,
                # 计算缺失占比，保留2位小数
                'missing_percentage': round(missing_count / len(df) * 100, 2)
            }
        # 多维度数据质量检查
        # 为什么只有评分字段，需要做多维度数据校验，其他字段，直接判断是否有缺失值即可？
        # 评分是数值型，数值型可以进行数学运算（max,min,mean）
        # 其他字段基本上都是字符串类型
        validation_result['data_quality'] = {
            'has_rating': df['评分'].mean() > 0,  # 判断这批爬取的数据 是否包含有效的评分信息
            # isnull():判断每个电影名是否为空  all()是否全为空  not 只要有一个非空
            'has_movie_names': not df['电影名'].isnull().all(),  # 是否至少有一部电影名有效
            'avg_rating': round(df['评分'].mean(), 2),  # 计算平均评分并保留两位小数（可以看整体水平）
            'max_rating': round(df['评分'].max(), 2),  # 获取最高评分并保留两位小数（判断数据范围是否正确）
            'min_rating': round(df['评分'].min(), 2),  # 获取最低评分并保留两位小数（判断数据范围是否正确）
            # '评价人数' in df.columns:检查列是否存在  sum() 存在则求和  int 转为整数  else 0 不存在拿到0
            'total_ratings': int(df['评价人数'].sum()) if '评价人数' in df.columns else 0,  # 安全计算总评价人数
            # 检查列是否存在  存在则统计非空值数量
            'has_year_info': df['上映年份'].notna().sum() if '上映年份' in df.columns else 0,
            'has_genre_info': df['电影类型'].notna().sum() if '电影类型' in df.columns else 0,
            'has_summary': df['简介'].notna().sum() if '简介' in df.columns else 0,
            'has_director_info': df['导演'].notna().sum() if '导演' in df.columns else 0,
            'has_actor_info': df['演员'].notna().sum() if '演员' in df.columns else 0
        }
        return validation_result

# 爬虫要调试，是因为网络请求和HTML解析容易出错，调试能快速定位问题
def debug_single_page():
    """调试单页数据"""
    config = Config()
    spider = DoubanMovieSpider(config)
    # 只爬取第一页用于调试
    # 获取第1页数据(索引从0开始)    98行
    movies = spider.get_page_data(0)
    if movies:
        print(f"\n获取到{len(movies)}部电影:")
        # 显示有简介和无简介的电影
        with_intro = [m for m in movies if m['简介']]
        without_intro = [m for m in movies if not m['简介']]
        print(f"有简介的电影: {len(with_intro)} 部")
        print(f"无简介的电影: {len(without_intro)} 部")

        print("\n前5部电影完整信息:")
        for i,movie in enumerate(movies[:5]):
            print(f"\n第 {i+1} 部电影:")
            for key,value in movie.items():
                print(f"   {key}: {value}")
        # 保存调试数据
        df = pd.DataFrame(movies)
        debug_path = "debug_movies.csv"
        df.to_csv(debug_path, index=False, encoding='utf-8-sig')
        print(f"\n调试数据已保存到: {debug_path}")
    else:
        print("未获取到电影数据")

if __name__ == "__main__":
    # 调试模式:python spiders/douban_spider.py --debug
    if len(sys.argv) > 1 and sys.argv[1] == "debug":
        debug_single_page()
    else:  # 非调试模式: python spiders/douban_spider.py
        config = Config()
        spider = DoubanMovieSpider(config)
        # 爬取所有电影
        df = spider.crawl_all_movies()

        if not df.empty:
            print(f"\n爬取完成！共获取{len(df)}部电影")
            print(f"数据已保存到: {config.DOUBAN_MOVIE_PATH}")
            print(f"文本格式已保存到: {config.DOUBAN_TEXT_PATH}")
            # 显示有简介的提取情况
            summary_with_intro = df['简介'].notna().sum()
            print(f"简介提取情况: {summary_with_intro}/{len(df)} 部电影有简介")
            # 显示前5部电影的完整信息用于验证
            print("\n前5部电影数据（用于验证解析是否正确）:")
            for i,row in df.head(5).iterrows():
                print(f"\n{i + 1}. {row['电影名']}")
                print(f"   评分: {row['评分']} | 评价人数: {row['评价人数']:,}")
                print(f"   导演: {row.get('导演', '')}")
                print(f"   演员: {row.get('演员', '')}")
                print(f"   上映年份: {row.get('上映年份', '')}")
                print(f"   国家地区: {row.get('国家地区', '')}")
                print(f"   电影类型: {row.get('电影类型', '')}")
                if pd.notna(row.get('简介')):
                    print(f"   简介: {row['简介']}")
                else:
                    print(f"   简介: (无简介)")
        else:
            print("爬取失败，未获取到数据")