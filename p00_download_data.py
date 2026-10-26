# Tải bộ Olist thật từ thư mục Google Drive về Downloads/raw_olist/ rồi kiểm tra đủ 8 file.
# Cách chạy:  p00_download_data.py
# Trong VS Code, cài gdown bằng cách mở Terminal tích hợp (hoặc Command Prompt/PowerShell) và chạy lệnh: python -m pip install gdown


import glob, os, shutil, sys
URL = 'https://drive.google.com/drive/folders/19hxqzei43tE8DW-QwclDAMsoFucSGFR_'
NEED = ['olist_orders_dataset', 'olist_order_items_dataset', 'olist_customers_dataset', 'olist_sellers_dataset',
        'olist_products_dataset', 'product_category_name_translation', 'olist_order_payments_dataset', 'olist_order_reviews_dataset']
RAW_DIR = os.path.join(os.path.expanduser('~'), 'Downloads', 'raw_olist')   # Folder lưu dữ liệu gốc tải về từ Google Drive được lưu trong Downloads/raw_olist/...
try:
    import gdown
except ImportError:
    sys.exit('Chưa cài gdown: chạy  pip install gdown')
os.makedirs(RAW_DIR, exist_ok=True)
try:
    gdown.download_folder(URL, output=RAW_DIR, quiet=False, use_cookies=False)
except Exception as e:
    print('Tải lỗi:', e); print('→ Thư mục phải để chế độ "Anyone with the link", hoặc tải tay (xem README mục 2.2).'); sys.exit(1)
# gdown có thể tạo thư mục con (và giải nén zip nếu có): đưa mọi CSV ra thẳng raw_olist/
for f in glob.glob(os.path.join(RAW_DIR, '**', '*.csv'), recursive=True):
    dst = os.path.join(RAW_DIR, os.path.basename(f))
    if os.path.abspath(f) != os.path.abspath(dst): shutil.move(f, dst)
have = {os.path.basename(f)[:-4] for f in glob.glob(os.path.join(RAW_DIR, '*.csv'))}
missing = [n for n in NEED if n not in have]
print('Đã có:', sorted(have & set(NEED)))
if missing: print('THIẾU:', missing); sys.exit(1)
print('ĐÃ HOÀN THÀNH — đủ 8 file CSV trong', RAW_DIR)

# Kiểm tra nhanh dữ liệu đã đúng chưa:
import pandas as pd
o = pd.read_csv(os.path.join(RAW_DIR, 'olist_orders_dataset.csv')); i = pd.read_csv(os.path.join(RAW_DIR, 'olist_order_items_dataset.csv'))
print(len(o), len(i), o.order_status.value_counts().to_dict())
