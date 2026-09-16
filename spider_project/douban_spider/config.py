# os 是 Python ‌内置标准库
import os
from datetime import datetime

class Config:
    """项目配置类"""
    # 项目路径（提取目录部分(去掉文件名)）
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    # 项目下添加一个data目录
    DATA_DIR = os.path.join(BASE_DIR, 'data')
    # 在data目录下添加一个cleaned目录
    RAW_DATA_DIR = os.path.join(DATA_DIR, 'raw')
    # 在data目录下添加一个cleaned目录
    CLEANED_DATA_DIR = os.path.join(DATA_DIR, 'cleaned')
    # 在data目录下添加一个processed目录
    PROCESSED_DATA_DIR = os.path.join(DATA_DIR, 'processed')
    # 在data目录下添加一个visualization目录
    VISUALIZATION_DIR = os.path.join(DATA_DIR, 'visualization')
    # 在项目根目录下添加一个logs日志目录
    LOGS_DIR = os.path.join(BASE_DIR, 'logs')

    # 定义HTTP请求头字典，模拟浏览器访问豆瓣
    # 伪装爬虫请求，降低被豆瓣反爬机制，识别和封禁的风险
    HEADERS = {
        # 告诉服务器「我是谁」 操作系统：Windows 10 浏览器内核：AppleWebKit / Chrome  浏览器版本：Edge 120
        # 防止被直接当成爬虫
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
        # 告诉服务器「我能接受哪些类型的响应内容」 HTML 网页  XHTML  WebP 图片  */*：其他任意类型   q权重（优先级）
        # 模拟真实浏览器的请求头，增加识别为正常用户的概率
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
        # 告诉服务器「我希望看到什么语言」 zh-CN：简体中文  en：英语  q=：偏好权重
        # 减少被识别为海外爬虫的可能
        'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
        # 告诉服务器「我支持哪些压缩方式」  gzip / deflate：常见压缩  br：Brotli（现代浏览器支持）
        # 减小传输体积
        # 没有这行，某些站点会拒绝请求
        'Accept-Encoding': 'gzip, deflate, br',
        # 复用 TCP 连接，减少重复握手次数（更像真实浏览器行为）
        'Connection': 'keep-alive',
        # 来源页面
        'Referer': 'https://www.douban.com/',
        # 告诉服务器「我支持 HTTPS，请把 HTTP 自动升级成 HTTPS」 1：支持 0：不支持
        'Upgrade-Insecure-Requests': '1',
        # 这里表示：我要加载一个页面  document：网页文档  image：图片 xhr：Ajax 请求
        'Sec-Fetch-Dest': 'document',
        # 请求的导航模式
        # navigate：浏览器地址栏直接访问 cors：跨域请求 no-cors：简单请求  same-origin：同源请求  unsafe-navigate：不安全导航请求
        'Sec-Fetch-Mode': 'navigate',
        # 请求发起方和目标站点的关系
        # same-origin：同源请求  cross-origin：跨源请求  same-site：同站  none：地址栏输入
        'Sec-Fetch-Site': 'same-origin',
        # 缓存控制策略
        # max-age=0：不缓存  max-age=3600：缓存1小时
        # 模拟浏览器刷新行为 防止拿到旧页面
        'Cache-Control': 'max-age=0',
    }

    # 在raw目录下添加一个csv文件
    DOUBAN_MOVIE_PATH = os.path.join(RAW_DATA_DIR, 'douban_movies_raw.csv')
    # 在raw目录下添加一个txt文件
    DOUBAN_TEXT_PATH = os.path.join(RAW_DATA_DIR, 'douban_top250.txt')
    # 数据清洗后路径（在cleaned目录下添加一个csv文件）
    CLEANED_MOVIE_DATA_PATH = os.path.join(RAW_DATA_DIR, 'douban_movies_cleaned.csv')
    # 设置Matplotlib的图表样式
    # Seaborn 调色板
    # 使用Seaborn 0.8版本的默认美化样式
    PLOT_STYLE = 'seaborn-v0_8'
    # 定义画布的默认尺寸（宽度12英寸，高度8英寸）
    FIGURE_SIZE = (12, 8)
    # 设置图表的分辨率
    # 300 高分辨率标准
    DPI = 300
    # 这个颜色方案字典，是为整个项目提供统一的配色规范
    COLOR_PALETTES = {
        # 柱状图、热力图中表示数量大小
        'sequential': ['viridis', 'plasma', 'summer', 'wistia'],  # 渐变色系
        # 相关性热力图
        'diverging': ['RdBu', 'Spectral', 'coolwarm', 'PiYG'],  # 发散色系
        # 多类别对比
        'categorical': ['tab20c', 'Set3', 'tab20', 'Pastel2']  # 分类色系
    }
    # 记录INFO及以上级别的日志
    # 日志等级（从低到高）：debug（调试）、info（正常运行）、warning（警告信息）、error（错误信息）、critical（严重错误）
    LOG_LEVEL = 'INFO'

    # 注意：这里使用属性而不是类变量，确保每次获取时都是最新时间
    @property
    def LOG_FILE(self):
        # 构建完整的日志文件路径，例如：logs/app_20230629.log
        # strftime("%Y%m%d"):格式化为年月日(如20260629)
        return os.path.join(self.LOGS_DIR, f'{datetime.now().strftime("%Y%m%d")}.log')

    # 豆瓣爬虫配置
    DOUBAN_CONFIG = {
        # 爬取的路径
        'base_url': 'https://movie.douban.com/top250',
        # 网络请求失败后，允许最大重试次数
        'max_retries': 3,
        # 请求超时时间，防止爬虫无限等待
        'timeout': 10,
        # 随机延迟范围
        'delay_range': (1, 3),
        # 最大爬取页数
        'max_pages': 10,
    }

    # 绑定类方法
    @classmethod
    def init_directories(cls):
        """
        初始化项目所需要的目录
        """
        dirs_to_create = [
            cls.DATA_DIR,
            cls.RAW_DATA_DIR,
            cls.CLEANED_DATA_DIR,
            cls.PROCESSED_DATA_DIR,
            cls.VISUALIZATION_DIR,
            cls.LOGS_DIR,
        ]
        # 批量创建项目所需目录
        for dir_path in dirs_to_create:
            # 创建 目录
            # exist_ok=True表示目录已存在时不报错
            os.makedirs(dir_path, exist_ok=True)
            print(f"{dir_path} 的路径创建成功！")

if __name__ == '__main__':
    # 测试配置
    config = Config()
    Config.init_directories()
    print(f"LOG_FILE:{config.LOG_FILE}")