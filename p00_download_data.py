# Tải bộ Olist thật từ thư mục Google Drive về data/ rồi kiểm tra đủ 8 file.
# Cách chạy:  pip install gdown && python download_data.py
# Trong VS Code, cài gdown bằng cách mở Terminal tích hợp (hoặc Command Prompt/PowerShell) và chạy lệnh: python -m pip install gdown


import glob, os, shutil, sys
URL = 'https://drive.google.com/drive/folders/19hxqzei43tE8DW-QwclDAMsoFucSGFR_'
NEED = ['olist_orders_dataset', 'olist_order_items_dataset', 'olist_customers_dataset', 'olist_sellers_dataset',
        'olist_products_dataset', 'product_category_name_translation', 'olist_order_payments_dataset', 'olist_order_reviews_dataset']
try:
    import gdown
except ImportError:
    sys.exit('Chưa cài gdown: chạy  pip install gdown')
os.makedirs('data', exist_ok=True)
try:
    gdown.download_folder(URL, output='data', quiet=False, use_cookies=False)
except Exception as e:
    print('Tải lỗi:', e); print('→ Thư mục phải để chế độ "Anyone with the link", hoặc tải tay (xem README mục 2.2).'); sys.exit(1)
# gdown có thể tạo thư mục con (và giải nén zip nếu có): đưa mọi CSV ra thẳng data/
for f in glob.glob('data/**/*.csv', recursive=True):
    dst = os.path.join('data', os.path.basename(f))
    if os.path.abspath(f) != os.path.abspath(dst): shutil.move(f, dst)
have = {os.path.basename(f)[:-4] for f in glob.glob('data/*.csv')}
missing = [n for n in NEED if n not in have]
print('Đã có:', sorted(have & set(NEED)))
if missing: print('THIẾU:', missing); sys.exit(1)
print('ĐÃ HOÀN THÀNH — đủ 8 file CSV trong data/')

# Kiểm tra nhanh dữ liệu đã đúng chưa:
import pandas as pd
o = pd.read_csv('data/olist_orders_dataset.csv'); i = pd.read_csv('data/olist_order_items_dataset.csv')
print(len(o), len(i), o.order_status.value_counts().to_dict())
