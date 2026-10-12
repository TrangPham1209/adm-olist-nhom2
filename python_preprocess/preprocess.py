# ===== TIỀN XỬ LÝ + TRỰC QUAN HOÁ QUÁ TRÌNH TIỀN XỬ LÝ =====
# Nguyên tắc: (1) dựng bảng ĐÚNG GRAIN (1 dòng = 1 order item) NGAY TỪ ĐẦU, không join thô rồi sửa sau;
#             (2) mỗi bước đều ghi vào nhật ký `log` để vẽ funnel; (3) có kiểm tra tự động (assert) cuối script.
# ---------- CẤU HÌNH ĐƯỜNG DẪN (tích hợp sẵn, file này chạy độc lập — không cần config.py) ----------
# Khắc phục lỗi FileNotFoundError khi chạy bằng Code Runner/IDE: tự chuyển về thư mục chứa script và tự tìm 8 file CSV.
import os, sys
from pathlib import Path
BASE = Path(__file__).resolve().parent if '__file__' in globals() else Path.cwd()
os.chdir(BASE)                                                        # thư mục làm việc = thư mục chứa script
OUT_DIR = BASE / 'preprocess_out'      # NƠI LƯU dữ liệu sau tiền xử lý (CSV/pkl), nhật ký, bảng thiếu
FIG_DIR = BASE / 'preprocess_figs'     # NƠI LƯU hình trực quan hoá tiền xử lý
for _d in (OUT_DIR, FIG_DIR): _d.mkdir(exist_ok=True)
try: sys.stdout.reconfigure(encoding='utf-8')                         # in tiếng Việt trên console Windows
except Exception: pass
# >>> Nếu data nằm chỗ khác, sửa đường dẫn thư mục chứa 8 file CSV ở đây (hoặc đặt biến môi trường OLIST_DATA):
DATA_DIR_OVERRIDE = r'C:\Users\QUOC ANH\Downloads\final_code'
def find_data_dir(required='olist_orders_dataset.csv'):
    home = Path.home()
    cands = [DATA_DIR_OVERRIDE, os.environ.get('OLIST_DATA'), BASE / 'data', BASE, BASE.parent / 'data', BASE.parent,
             home / 'Downloads' / 'final_code' / 'data', home / 'Downloads' / 'final_code', home / 'Downloads' / 'data', home / 'Downloads']
    for c in cands:
        if c and (Path(c) / required).exists(): return str(Path(c)) + os.sep
    for p in BASE.rglob(required): return str(p.parent) + os.sep   # tìm đệ quy trong thư mục dự án
    raise FileNotFoundError(f'Không tìm thấy {required}. Chép 8 CSV Olist vào {BASE / "data"} hoặc sửa DATA_DIR_OVERRIDE ở đầu file.\n'
                            'Đã tìm ở: ' + '; '.join(str(c) for c in cands if c))

import pandas as pd, numpy as np, matplotlib, textwrap
matplotlib.use('Agg'); import matplotlib.pyplot as plt
D = find_data_dir(); print('Đọc dữ liệu từ:', D)

# ---------- 0. Nạp dữ liệu ----------
orders = pd.read_csv(D+'olist_orders_dataset.csv', parse_dates=['order_purchase_timestamp','order_approved_at',
          'order_delivered_carrier_date','order_delivered_customer_date','order_estimated_delivery_date'])
items = pd.read_csv(D+'olist_order_items_dataset.csv', parse_dates=['shipping_limit_date'])
customers = pd.read_csv(D+'olist_customers_dataset.csv'); sellers = pd.read_csv(D+'olist_sellers_dataset.csv')
products = pd.read_csv(D+'olist_products_dataset.csv'); trans = pd.read_csv(D+'product_category_name_translation.csv')
payments = pd.read_csv(D+'olist_order_payments_dataset.csv')
reviews = pd.read_csv(D+'olist_order_reviews_dataset.csv', parse_dates=['review_creation_date','review_answer_timestamp'])
products = products.merge(trans, on='product_category_name', how='left')      # thêm tên category tiếng Anh

log = []                                   # nhật ký: (bước, số dòng, ghi chú)
def step(name, n, note=''): log.append((name, n, note))

# ---------- Bước 0 (CHỈ ĐỂ MINH CHỨNG): join thô → fan-out ----------
naive = orders.merge(items, on='order_id').merge(payments, on='order_id', how='left').merge(reviews, on='order_id', how='left')
step('0. Join thô orders+items+payments+reviews', len(naive), 'bị fan-out — chỉ để so sánh, KHÔNG dùng')
GMV_naive    = naive.query("order_status=='delivered'").price.sum()
GMV_true_raw = items.merge(orders[['order_id','order_status']], on='order_id').query("order_status=='delivered'").price.sum()

# ---------- Bước 1: dựng bảng đúng grain (1 dòng = 1 order item) ----------
df = (orders.merge(items, on='order_id', how='inner')
            .merge(customers, on='customer_id', how='left')
            .merge(sellers, on='seller_id', how='left')
            .merge(products, on='product_id', how='left'))
step('1. Orders ⋈ Items ⋈ Customer ⋈ Seller ⋈ Product (đúng grain)', len(df))

# ---------- Bước 2: chỉ giữ đơn đã hoàn tất ----------
df = df[df.order_status == 'delivered'].copy()
step('2. Chỉ giữ đơn delivered', len(df))

# ---------- Bước 3: gộp payment (SUM) + khử trùng review TRƯỚC khi nối → hết fan-out ----------
payment_agg = (payments.sort_values('payment_value', ascending=False).groupby('order_id')
    .agg(total_payment_value=('payment_value', 'sum'), n_payment_methods=('payment_type', 'nunique'),
         max_installments=('payment_installments', 'max'),
         main_payment_type=('payment_type', 'first')      # phương thức có giá trị lớn nhất trong đơn
         ).reset_index())
reviews_dedup = reviews.sort_values('review_answer_timestamp').drop_duplicates('order_id', keep='last')   # giữ review mới nhất
df = (df.merge(payment_agg, on='order_id', how='left')
        .merge(reviews_dedup[['order_id', 'review_score']], on='order_id', how='left'))
step('3. Gộp payment (SUM) + khử trùng review (giữ mới nhất)', len(df), 'không đổi số dòng => hết fan-out')
GMV_fixed = df.price.sum()

# ---------- Bước 4: xử lý thiếu + tạo cột dẫn xuất ----------
CHECK_COLS = ['product_category_name_english', 'review_score', 'order_delivered_customer_date']
miss_before = df[CHECK_COLS].isna().mean() * 100
df['product_category_name_english'] = df['product_category_name_english'].fillna('unknown')   # category thiếu → 'unknown'
df['delivery_days']   = (df.order_delivered_customer_date - df.order_purchase_timestamp).dt.total_seconds() / 86400
df['estimated_days']  = (df.order_estimated_delivery_date - df.order_purchase_timestamp).dt.total_seconds() / 86400
df['is_late']         = (df.order_delivered_customer_date > df.order_estimated_delivery_date).astype(int)
df['freight_ratio']   = df.freight_value / df.price
df['total_item_value'] = df.price + df.freight_value
dd_before = df.delivery_days.copy()                       # để vẽ phân phối TRƯỚC xử lý outlier
df = df.dropna(subset=['delivery_days'])                  # đơn 'delivered' nhưng thiếu ngày giao: không impute (là biến nghiệp vụ chính)
step('4. Bỏ dòng thiếu ngày giao', len(df))

# ---------- Bước 5: loại outlier delivery_days ----------
df = df[(df.delivery_days >= 0) & (df.delivery_days <= 200)].copy()     # âm = lỗi nhập; >200 ngày = bất thường
step('5. Loại outlier delivery_days ∉ [0,200]', len(df))

# ---------- Bước 6: chuẩn hoá text + impute review_score ----------
df['customer_city'] = df.customer_city.str.strip().str.title()
df['seller_city']   = df.seller_city.str.strip().str.title()
df['review_score']  = df.review_score.fillna(df.review_score.median())   # impute trung vị
step('6. Chuẩn hoá text + impute review_score (median)', len(df))
miss_after = df[['product_category_name_english', 'review_score', 'delivery_days']].isna().mean() * 100

# ---------- Kiểm tra tự động (chạy sai là dừng ngay) ----------
assert df.duplicated(['order_id', 'order_item_id']).sum() == 0, 'còn trùng grain → vẫn fan-out'
assert (df.order_status == 'delivered').all()
assert df[['price', 'freight_value', 'delivery_days', 'review_score']].notna().all().all(), 'còn NaN ở cột then chốt'
assert GMV_fixed <= GMV_true_raw + 1e-6 and GMV_fixed < GMV_naive, 'GMV sau xử lý phải ≤ GMV gốc và < GMV join thô'
# ---------- XUẤT DỮ LIỆU SAU TIỀN XỬ LÝ → preprocess_out/ ----------
df.to_pickle(OUT_DIR / 'df_delivered.pkl')                                      # giữ nguyên kiểu dữ liệu (datetime…) cho p02–p08
df.to_csv(OUT_DIR / 'olist_preprocessed.csv', index=False, encoding='utf-8-sig') # bản CSV mở được bằng Excel
pd.DataFrame(log, columns=['Bước', 'Số dòng', 'Ghi chú']).to_csv(OUT_DIR / 'prep_log.csv', index=False, encoding='utf-8-sig')

# ---------- TRỰC QUAN HOÁ (4 panel) ----------
fig, ax = plt.subplots(2, 2, figsize=(15, 9.5)); ax = ax.ravel()
names = [l[0] for l in log[1:]]; vals = [l[1] for l in log[1:]]            # bỏ bước 0 (chỉ minh chứng)
ax[0].barh(range(len(vals))[::-1], vals, color='#FFCA41', edgecolor='k')
ax[0].set_yticks(range(len(vals))[::-1]); ax[0].set_yticklabels([textwrap.fill(n, 38) for n in names], fontsize=8)
for i, v in enumerate(vals): ax[0].text(v, len(vals)-1-i, f' {v:,}', va='center', fontsize=8)
ax[0].set_title('(a) Funnel số dòng qua từng bước'); ax[0].set_xlim(0, max(vals)*1.18)
G = [GMV_naive, GMV_fixed, GMV_true_raw]
ax[1].bar(['Join thô\n(sai grain)', 'Đúng grain\n(sau bước 3)', 'Nguồn gốc\n(items gốc)'], G, color=['#d9534f', '#5cb85c', '#999'])
for i, v in enumerate(G): ax[1].text(i, v, f'{v:,.0f}', ha='center', va='bottom', fontsize=9)
ax[1].set_title(f'(b) Kiểm tra fan-out: GMV delivered (join thô cao hơn {GMV_naive/GMV_true_raw-1:.1%})')
ax[2].hist(dd_before.dropna().clip(lower=-10, upper=80), bins=60, alpha=.5, label='trước', color='#d9534f')
ax[2].hist(df.delivery_days.clip(upper=80), bins=60, alpha=.6, label='sau', color='#5cb85c')
ax[2].set_title('(c) delivery_days trước/sau xử lý outlier (cắt trục ở 80)'); ax[2].legend()
mm = pd.DataFrame({'Trước': miss_before.values, 'Sau': [0.0, 0.0, 0.0]}, index=['category_en', 'review_score', 'delivery_days'])
mm.loc['delivery_days', 'Trước'] = dd_before.isna().mean() * 100
mm.loc['delivery_days', 'Sau'] = miss_after['delivery_days']; mm.loc['category_en', 'Sau'] = miss_after['product_category_name_english']; mm.loc['review_score', 'Sau'] = miss_after['review_score']
mm.plot.bar(ax=ax[3], color=['#d9534f', '#5cb85c'], edgecolor='k'); ax[3].set_ylabel('% dòng thiếu'); ax[3].tick_params(axis='x', rotation=0)
for c in ax[3].containers: ax[3].bar_label(c, fmt='%.2f', fontsize=8)
ax[3].set_title('(d) Tỉ lệ thiếu trước/sau xử lý')
mm.round(3).to_csv(OUT_DIR / 'missing_before_after.csv', encoding='utf-8-sig')
plt.tight_layout(); plt.savefig(FIG_DIR / 'prep_overview.png', dpi=130); plt.close()

print(pd.DataFrame(log, columns=['Bước', 'Số dòng', 'Ghi chú']).to_string(index=False))
print(f"\nGMV join thô={GMV_naive:,.0f} | đúng grain={GMV_fixed:,.0f} | gốc={GMV_true_raw:,.0f}")
print("Missing % trước:\n", miss_before.round(2).to_string()); print("Missing % sau:\n", miss_after.round(2).to_string())
print("duplicated(order_id,order_item_id):", df.duplicated(['order_id', 'order_item_id']).sum())
print(f'\nĐã lưu: {OUT_DIR / 'olist_preprocessed.csv'} ({len(df):,} dòng × {df.shape[1]} cột), df_delivered.pkl, prep_log.csv, missing_before_after.csv')
print(f'Đã lưu hình: {FIG_DIR / 'prep_overview.png'}')

# ---------- Ghi chú giải thích (đưa vào báo cáo) ----------
# - Vì sao gộp payment trước khi join: tránh "fan-out" (Join sai grain) — đơn trả góp qua 2 thẻ sẽ bị đếm 2 lần nếu join trực tiếp.
# - Vì sao dựng đúng grain ngay từ đầu: nếu join thô payments/reviews, `price` bị cộng nhiều lần, mọi số liệu doanh thu và
#   `avg_review` của seller ở các mục sau đều sai. Kiểm tra: df.duplicated(['order_id','order_item_id']).sum() phải bằng 0.
# - Vì sao chỉ giữ order_status == 'delivered': đơn huỷ/đang giao có ý nghĩa nghiệp vụ khác, không trộn khi tính doanh thu/review thực nhận.
