# Tải bộ Olist thật từ thư mục Google Drive của nhóm về data/  (CHẠY TRÊN MÁY CÓ INTERNET — chưa được kiểm thử trong môi trường làm bài vì Drive bị chặn)
# pip install gdown
import gdown, os, glob
os.makedirs('data', exist_ok=True)
gdown.download_folder('https://drive.google.com/drive/folders/19hxqzei43tE8DW-QwclDAMsoFucSGFR_', output='data', quiet=False, use_cookies=False)
need = ['olist_orders_dataset','olist_order_items_dataset','olist_customers_dataset','olist_sellers_dataset','olist_products_dataset','product_category_name_translation','olist_order_payments_dataset','olist_order_reviews_dataset']
have = {os.path.basename(f)[:-4] for f in glob.glob('data/**/*.csv', recursive=True)}
print('Thiếu:', [n for n in need if n not in have] or 'không — đủ 8 file')
# Nếu gdown tạo thư mục con, chuyển CSV ra data/:  for f in glob.glob('data/*/*.csv'): os.replace(f, 'data/'+os.path.basename(f))
