# ===== TIỀN XỬ LÝ + TRỰC QUAN HOÁ QUÁ TRÌNH TIỀN XỬ LÝ =====
# Nguyên tắc: (1) dựng bảng ĐÚNG GRAIN (1 dòng = 1 order item) NGAY TỪ ĐẦU, không join thô rồi sửa sau;
#             (2) mỗi bước đều ghi vào nhật ký `log` để vẽ funnel; (3) có kiểm tra tự động (assert) cuối script.
# ⚠️ CHẠY CẢ FILE (bỏ bôi đen rồi bấm Run). Bôi đen một đoạn rồi Run → Code Runner chạy file tạm tempCodeRunnerFile.py, thiếu import/biến → NameError.
#    Muốn chạy riêng phần Descriptive (2.3): dùng p01b_descriptive.py (tự nạp preprocess_out/df_delivered.pkl).
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

# ---------- ALIAS cho phần Descriptive Analysis bên dưới ----------
# Phần phân tích mô tả (2.3) dùng tên `df_delivered` = bảng ĐÃ tiền xử lý (đúng grain, 1 dòng = 1 order item).
# Trong script này bảng đó đang tên `df` → gán alias (không copy thêm bộ nhớ). Nếu thiếu dòng này sẽ báo: NameError: name 'df_delivered' is not defined
df_delivered = df

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
print(f"\nĐã lưu: {OUT_DIR / 'olist_preprocessed.csv'} ({len(df):,} dòng × {df.shape[1]} cột), df_delivered.pkl, prep_log.csv, missing_before_after.csv")
print(f"Đã lưu hình: {FIG_DIR / 'prep_overview.png'}")

# ---------- Ghi chú giải thích nghiệp vụ  ---------- #
# - Vì sao gộp payment trước khi join: tránh "fan-out" (Join sai grain) — đơn trả góp qua 2 thẻ sẽ bị đếm 2 lần nếu join trực tiếp.
# - Vì sao dựng đúng grain ngay từ đầu: nếu join thô payments/reviews, `price` bị cộng nhiều lần, mọi số liệu doanh thu và
#   `avg_review` của seller ở các mục sau đều sai. Kiểm tra: df.duplicated(['order_id','order_item_id']).sum() phải bằng 0.
# - Vì sao chỉ giữ order_status == 'delivered': đơn huỷ/đang giao có ý nghĩa nghiệp vụ khác, không trộn khi tính doanh thu/review thực nhận.


### Descriptive Analysis (Phân tích mô tả trên dữ liệu đã tiền xử lý)

## Mục tiêu và khác biệt so với EDA ở mục 1:**
#- **EDA (mục 1)** chạy trên dữ liệu *thô*, mục đích là **phát hiện vấn đề** (fan-out, đơn huỷ, basket thưa) để quyết định cách tiền xử lý và hướng mining.
#- **Descriptive Analysis (mục này)** chạy trên dữ liệu *đã sạch*, mục đích là **định lượng bức tranh kinh doanh** (quy mô, thời vụ, địa lý, logistics, seller) và **rút insight có số liệu** làm cơ sở cho Data Warehouse (chọn chiều/hierarchy), Pattern Mining (chọn feature, cách rời rạc hoá) và nhãn Performance.

#> **Quy ước bắt buộc về grain (tránh tính trùng):** doanh thu tính trên mức *order item*; chỉ số "mỗi đơn một giá trị" (review, thời gian giao, giao trễ) phải tính trên mức *order*; chỉ số theo seller tính trên mức *seller*. Vì vậy phần này dựng 3 view riêng ở 2.3.0 và mọi phép tính phía sau chỉ dùng đúng view tương ứng.

# > **Về số liệu insight:** các con số cụ thể phải lấy từ output khi nhóm chạy trên dữ liệu Olist thật. Code ở 2.3.8 tự sinh câu insight kèm số liệu từ chính dữ liệu của nhóm; phần "kỳ vọng" ở 2.3.9 chỉ là giả thuyết cần đối chiếu, không phải kết quả.

#### 2.3.0 Chuẩn bị 3 view đúng grain

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats

sns.set_theme(style='whitegrid')

def save_fig(name):
    plt.tight_layout()
    plt.savefig(FIG_DIR / f'{name}.png', dpi=150)
    plt.close()

# View 1 — mức ORDER ITEM: dùng cho doanh thu, category, giá
items_d = df_delivered.copy()
items_d['same_state'] = (items_d['seller_state'] == items_d['customer_state'])

# View 2 — mức ORDER: dùng cho review, thời gian giao, giao trễ, thanh toán
orders_d = df_delivered.groupby('order_id').agg(
    purchase_ts=('order_purchase_timestamp', 'first'),
    delivered_ts=('order_delivered_customer_date', 'first'),
    estimated_ts=('order_estimated_delivery_date', 'first'),
    n_items=('order_item_id', 'count'),
    n_sellers=('seller_id', 'nunique'),
    gmv=('price', 'sum'),
    freight=('freight_value', 'sum'),
    delivery_days=('delivery_days', 'first'),
    is_late=('is_late', 'first'),
    review_score=('review_score', 'first'),
    customer_state=('customer_state', 'first'),
    payment_type=('main_payment_type', 'first'),
    installments=('max_installments', 'first'),
).reset_index()
orders_d['delay_days'] = (orders_d['delivered_ts'] - orders_d['estimated_ts']).dt.days

# View 3 — mức SELLER: dùng cho phân tích seller (cùng định nghĩa với seller_profile ở mục 4.2)
seller_desc = df_delivered.groupby('seller_id').agg(
    seller_state=('seller_state', 'first'),
    n_orders=('order_id', 'nunique'),
    gmv=('price', 'sum'),
    avg_price=('price', 'mean'),
    n_categories=('product_category_name_english', 'nunique'),
    avg_review=('review_score', 'mean'),
    avg_delivery_days=('delivery_days', 'mean'),
    late_rate=('is_late', 'mean'),
)
MIN_ORDERS = 10                                              # cùng ngưỡng lọc seller như p05_mining.py / p06_classify.py
seller_active = seller_desc[seller_desc['n_orders'] >= MIN_ORDERS]
print(f"Seller tổng: {len(seller_desc)} | Seller đủ điều kiện (>={MIN_ORDERS} đơn): {len(seller_active)}")


#### 2.3.1 Chỉ số tổng quan (KPI)

kpi = {
    'Số đơn hàng (delivered)': orders_d['order_id'].nunique(),
    'Số seller hoạt động': df_delivered['seller_id'].nunique(),
    'Số khách hàng (unique)': df_delivered['customer_unique_id'].nunique(),
    'Số category': df_delivered['product_category_name_english'].nunique(),
    'GMV - tổng giá trị hàng (BRL)': orders_d['gmv'].sum(),
    'Giá trị đơn trung bình - AOV (BRL)': orders_d['gmv'].mean(),
    'Số sản phẩm / đơn (trung bình)': orders_d['n_items'].mean(),
    'Tỷ lệ đơn chỉ có 1 sản phẩm': (orders_d['n_items'] == 1).mean(),
    'Điểm review trung bình': orders_d['review_score'].mean(),
    'Tỷ lệ đơn giao trễ': orders_d['is_late'].mean(),
    'Thời gian giao trung bình (ngày)': orders_d['delivery_days'].mean(),
    'Tổng phí ship / tổng giá hàng': orders_d['freight'].sum() / orders_d['gmv'].sum(),
}
print(pd.Series(kpi).round(3).to_string())
pd.Series(kpi).round(3).rename('value').to_csv(OUT_DIR / 'kpi_summary.csv', encoding='utf-8-sig')


# → Đưa bảng KPI này vào đầu phần "Dữ liệu và thực nghiệm" của báo cáo. Hai chỉ số **"Số sản phẩm / đơn"** và **"Tỷ lệ đơn chỉ có 1 sản phẩm"** là bằng chứng định lượng cho quyết định chuyển mining từ `order_id` sang `seller_id` (mục 4.1).

#### 2.3.2 Phân tích theo thời gian

monthly = (orders_d.assign(ym=orders_d['purchase_ts'].dt.to_period('M'))
           .groupby('ym').agg(n_orders=('order_id', 'nunique'), gmv=('gmv', 'sum')))
# Loại tháng đầu/cuối dataset có quá ít đơn (không đủ tháng) để không làm sai tốc độ tăng trưởng
monthly = monthly[monthly['n_orders'] >= 0.05 * monthly['n_orders'].max()]
monthly['mom_growth'] = monthly['n_orders'].pct_change()

fig, ax1 = plt.subplots(figsize=(10, 4))
ax1.bar(monthly.index.astype(str), monthly['n_orders'], color='steelblue', alpha=0.7)
ax1.set_ylabel('Số đơn'); ax1.tick_params(axis='x', rotation=90)
ax2 = ax1.twinx()
ax2.plot(monthly.index.astype(str), monthly['gmv'], color='darkorange', marker='o')
ax2.set_ylabel('GMV (BRL)')
plt.title('Số đơn và GMV theo tháng')
save_fig('02_monthly_orders_gmv')

peak_month = monthly['n_orders'].idxmax()
print("Tháng cao điểm:", peak_month, "| số đơn:", monthly.loc[peak_month, 'n_orders'])
print("Tăng trưởng MoM cao nhất:", monthly['mom_growth'].idxmax(), round(monthly['mom_growth'].max(), 3))

# Thứ trong tuần x Giờ trong ngày
orders_d['dow'] = orders_d['purchase_ts'].dt.dayofweek      # 0 = Thứ Hai
orders_d['hour'] = orders_d['purchase_ts'].dt.hour
heat = orders_d.pivot_table(index='dow', columns='hour', values='order_id', aggfunc='count', fill_value=0)
plt.figure(figsize=(11, 3.5))
sns.heatmap(heat, cmap='YlOrRd')
plt.title('Số đơn theo Thứ trong tuần (0 = Thứ Hai) x Giờ trong ngày')
save_fig('02_dow_hour_heatmap')


# **Cách đọc:** (1) đường tăng trưởng và tháng đột biến → có tính thời vụ/khuyến mãi lớn hay không (liên hệ vấn đề "promotion làm nhiễu support" đã học ở Apriori); (2) heatmap → khung giờ/ngày mua sắm cao điểm, phục vụ gợi ý thời điểm chạy chiến dịch.

#### 2.3.3 Phân tích địa lý (Seller và Customer)

seller_state_share = seller_desc['seller_state'].value_counts(normalize=True)
cust_state_share = orders_d['customer_state'].value_counts(normalize=True)
print("Top 5 bang của SELLER (tỷ lệ seller):\n", seller_state_share.head(5).round(3))
print("Top 5 bang của CUSTOMER (tỷ lệ đơn):\n", cust_state_share.head(5).round(3))
print("Top-1 / Top-3 bang chiếm bao nhiêu % seller:",
      round(seller_state_share.iloc[0], 3), "/", round(seller_state_share.head(3).sum(), 3))

# Giao nội bang vs liên bang — ảnh hưởng tới logistics và trải nghiệm
geo_cmp = items_d.groupby('same_state').agg(
    n_items=('order_item_id', 'count'),
    avg_delivery_days=('delivery_days', 'mean'),
    late_rate=('is_late', 'mean'),
    avg_review=('review_score', 'mean'),
    avg_freight_ratio=('freight_value', lambda x: (x / items_d.loc[x.index, 'price']).mean()),
).rename(index={True: 'Cùng bang', False: 'Khác bang'})
print(geo_cmp.round(3))

# Ma trận luồng hàng: bang seller (hàng) -> bang customer (cột), chuẩn hoá theo hàng
top_s = seller_state_share.head(5).index
top_c = cust_state_share.head(5).index
flow = pd.crosstab(items_d['seller_state'], items_d['customer_state'], normalize='index').loc[top_s, top_c]
plt.figure(figsize=(6, 4))
sns.heatmap(flow, annot=True, fmt='.2f', cmap='Blues')
plt.title('Luồng hàng: bang seller -> bang customer (tỷ lệ theo hàng)')
save_fig('02_state_flow')


# **Cách đọc:** mức tập trung địa lý của seller so với customer; chênh lệch thời gian giao/phí ship giữa giao nội bang và liên bang → cơ sở cho việc gắn `Region` vào `Dim_Geography` (mục 3.2) và giải thích vì sao vị trí seller ảnh hưởng đến Performance.

#### 2.3.4 Phân tích Category và giá

cat_gmv = items_d.groupby('product_category_name_english')['price'].sum().sort_values(ascending=False)
cat_share = cat_gmv / cat_gmv.sum()
cum_share = cat_share.cumsum()
n_cat_80 = int((cum_share < 0.8).sum() + 1)
print(f"{n_cat_80}/{len(cat_gmv)} category tạo ra 80% GMV")

fig, axes = plt.subplots(1, 2, figsize=(13, 4))
cat_gmv.head(10).sort_values().plot.barh(ax=axes[0], color='teal')
axes[0].set_title('Top 10 category theo GMV')
axes[1].plot(range(1, len(cum_share) + 1), cum_share.values, marker='.')
axes[1].axhline(0.8, color='red', ls='--'); axes[1].set_xlabel('Số category (xếp theo GMV giảm dần)')
axes[1].set_ylabel('Tỷ lệ GMV tích luỹ'); axes[1].set_title('Pareto GMV theo category')
save_fig('02_category_pareto')

top8 = cat_gmv.head(8).index
plt.figure(figsize=(11, 4))
sns.boxplot(data=items_d[items_d['product_category_name_english'].isin(top8)],
            x='product_category_name_english', y='price', showfliers=False)
plt.yscale('log'); plt.xticks(rotation=45, ha='right')
plt.title('Phân phối giá theo category (Top 8, thang log)')
save_fig('02_category_price_box')


# **Cách đọc:** số category tạo 80% GMV cho biết mức tập trung của danh mục (quy luật Pareto); boxplot cho biết category nào có giá phân tán mạnh → ảnh hưởng đến `avg_price`, `avg_freight_ratio` của seller.

#### 2.3.5 Logistics và trải nghiệm khách hàng (review)

fig, axes = plt.subplots(1, 2, figsize=(12, 4))
sns.histplot(orders_d['delivery_days'], bins=40, ax=axes[0], color='slateblue')
axes[0].axvline(orders_d['delivery_days'].median(), color='red', ls='--', label='Trung vị')
axes[0].legend(); axes[0].set_title('Phân phối thời gian giao hàng (ngày)')
orders_d['review_score'].value_counts().sort_index().plot.bar(ax=axes[1], color='seagreen')
axes[1].set_title('Phân phối điểm review (kiểm tra dạng chữ J)')
save_fig('02_delivery_review_dist')

# Mức độ trễ -> điểm review
bins_delay = [-np.inf, 0, 3, 7, np.inf]
labels_delay = ['Đúng/sớm hẹn', 'Trễ 1-3 ngày', 'Trễ 4-7 ngày', 'Trễ >7 ngày']
orders_d['delay_bucket'] = pd.cut(orders_d['delay_days'], bins=bins_delay, labels=labels_delay)
delay_tbl = orders_d.groupby('delay_bucket', observed=True).agg(
    n_orders=('order_id', 'count'),
    avg_review=('review_score', 'mean'),
    pct_low_review=('review_score', lambda s: (s <= 2).mean()),
)
print(delay_tbl.round(3))

plt.figure(figsize=(7, 4))
delay_tbl['avg_review'].plot.bar(color='indianred')
plt.ylabel('Điểm review trung bình'); plt.xticks(rotation=0)
plt.title('Điểm review theo mức độ giao trễ')
save_fig('02_review_by_delay')

# Kiểm định thống kê: review của đơn trễ có thấp hơn đơn đúng hẹn không?
late = orders_d.loc[orders_d['is_late'] == 1, 'review_score'].dropna()
ontime = orders_d.loc[orders_d['is_late'] == 0, 'review_score'].dropna()
u_stat, p_mw = stats.mannwhitneyu(late, ontime, alternative='less')
rho, p_sp = stats.spearmanr(orders_d['delivery_days'], orders_d['review_score'], nan_policy='omit')
print(f"Review TB: trễ = {late.mean():.2f} | đúng hẹn = {ontime.mean():.2f} | Mann-Whitney p = {p_mw:.2e}")
print(f"Spearman(delivery_days, review_score) = {rho:.3f} (p = {p_sp:.2e})")


# **Cách đọc:** dùng Mann-Whitney và Spearman (phi tham số) vì `review_score` là biến thứ tự, phân phối lệch hai cực — không dùng t-test. Kết quả này là **bằng chứng thống kê** cho việc dùng `late_rate` và `avg_review` làm tiêu chí nhãn Performance ở mục 4.5.

#### 2.3.6 Phân tích thanh toán

pay_share = orders_d['payment_type'].value_counts(normalize=True)
print("Tỷ trọng phương thức thanh toán chính:\n", pay_share.round(3))
print("AOV theo phương thức:\n", orders_d.groupby('payment_type')['gmv'].mean().round(1))

fig, axes = plt.subplots(1, 2, figsize=(12, 4))
pay_share.plot.bar(ax=axes[0], color='goldenrod'); axes[0].set_title('Tỷ trọng phương thức thanh toán')
orders_d['installments'].clip(upper=12).value_counts().sort_index().plot.bar(ax=axes[1], color='peru')
axes[1].set_title('Số kỳ trả góp tối đa của đơn (gộp >=12)')
save_fig('02_payment')


#### 2.3.7 Phân tích Seller (trọng tâm của đồ án)

# (a) Thống kê mô tả + độ lệch (skewness) — cơ sở chọn log-transform và qcut ở mục 4.4
cols = ['n_orders', 'gmv', 'avg_price', 'n_categories', 'avg_review', 'avg_delivery_days', 'late_rate']
print(seller_active[cols].describe().round(2))
skew = seller_active[cols].skew().sort_values(ascending=False)
print("Độ lệch (skewness):\n", skew.round(2))
print("Feature lệch mạnh (|skew| > 1):", skew[skew.abs() > 1].index.tolist())

# (b) Đuôi dài và mức tập trung: Lorenz curve + Gini trên GMV
g = np.sort(seller_desc['gmv'].values)
lorenz = np.insert(np.cumsum(g) / g.sum(), 0, 0)
x = np.linspace(0, 1, len(lorenz))
trapezoid = getattr(np, 'trapezoid', None) or np.trapz   # tương thích NumPy 1.x và 2.x (np.trapz đã bị gỡ ở bản mới)
gini = 1 - 2 * trapezoid(lorenz, x)
top10_share = seller_desc['gmv'].nlargest(max(1, int(0.1 * len(seller_desc)))).sum() / seller_desc['gmv'].sum()
pct_small = (seller_desc['n_orders'] < MIN_ORDERS).mean()
print(f"Gini(GMV theo seller) = {gini:.3f} | Top 10% seller chiếm {top10_share:.1%} GMV | "
      f"{pct_small:.1%} seller có < {MIN_ORDERS} đơn (bị loại ở bước mining)")

plt.figure(figsize=(5, 5))
plt.plot(x, lorenz, label='Lorenz GMV'); plt.plot([0, 1], [0, 1], 'k--', label='Bình đẳng tuyệt đối')
plt.xlabel('Tỷ lệ seller tích luỹ'); plt.ylabel('Tỷ lệ GMV tích luỹ'); plt.legend()
plt.title('Đường Lorenz của GMV theo seller')
save_fig('02_seller_lorenz')

# (c) Quy mô có đi cùng chất lượng không?
rho_sz, p_sz = stats.spearmanr(seller_active['n_orders'], seller_active['avg_review'])
plt.figure(figsize=(6, 4))
plt.scatter(np.log1p(seller_active['n_orders']), seller_active['avg_review'], alpha=0.4, s=12)
plt.xlabel('log(1 + số đơn)'); plt.ylabel('Điểm review trung bình')
plt.title(f'Quy mô vs chất lượng (Spearman = {rho_sz:.2f})')
save_fig('02_seller_scale_vs_quality')

# (d) Xem trước nhãn Performance (cùng quy tắc p05/p06: Good nếu avg_review >= 4.0; late_rate là FEATURE, không dùng để gán nhãn) — kiểm tra mất cân bằng lớp
good_mask = (seller_active['avg_review'] >= 4.0)
pct_good = good_mask.mean()
print(f"Xem trước nhãn: Good = {pct_good:.1%} | NeedsSupport = {1 - pct_good:.1%}")

# (e) Vị trí seller và tỷ lệ giao trễ (chỉ bang có đủ seller để so sánh)
state_tbl = (seller_active.groupby('seller_state')
             .agg(n_sellers=('gmv', 'size'), late_rate=('late_rate', 'mean'), avg_review=('avg_review', 'mean'))
             .query('n_sellers >= 10').sort_values('late_rate', ascending=False))
print(state_tbl.round(3).head(10))


##**Cách đọc:**
#- **(a)** feature nào lệch mạnh → chứng minh cần `np.log1p` khi clustering (5.2.2) và cần `pd.qcut` thay vì `pd.cut` khi rời rạc hoá (4.4).
#- **(b)** Gini cao + top 10% seller chiếm tỷ trọng lớn → thị trường theo mô hình "ít seller lớn, nhiều seller nhỏ"; tỷ lệ seller < 5 đơn cho biết dữ liệu bị loại ở 4.2.
#- **(c)** nếu Spearman gần 0 → quy mô không bảo đảm chất lượng, là lý do cần phân khúc theo hiệu suất chứ không chỉ theo doanh số.
#- **(d)** tỷ lệ Good/NeedsSupport thực tế cho biết trước mức mất cân bằng lớp — liên quan trực tiếp đến hệ quả của minsup toàn cục ở 4.6 và bước chọn luật cân bằng 2 lớp ở 4.8.

#### 2.3.8 Tự động sinh câu insight kèm số liệu


insights = []

pct_single = (orders_d['n_items'] == 1).mean()
insights.append(f"[Basket thưa] {pct_single:.1%} đơn chỉ có 1 sản phẩm (trung bình {orders_d['n_items'].mean():.2f} "
                f"sản phẩm/đơn) -> mining theo order_id không khả thi, chuyển sang mức Seller.")

insights.append(f"[Thời vụ] Tháng cao điểm là {peak_month} với {int(monthly.loc[peak_month, 'n_orders'])} đơn; "
                f"tăng trưởng MoM cao nhất {monthly['mom_growth'].max():.1%} ({monthly['mom_growth'].idxmax()}).")

insights.append(f"[Địa lý] Bang đứng đầu chiếm {seller_state_share.iloc[0]:.1%} số seller "
                f"(top-3 chiếm {seller_state_share.head(3).sum():.1%}); "
                f"giao khác bang mất {geo_cmp.loc['Khác bang', 'avg_delivery_days']:.1f} ngày so với "
                f"{geo_cmp.loc['Cùng bang', 'avg_delivery_days']:.1f} ngày khi cùng bang.")

insights.append(f"[Danh mục] {n_cat_80}/{len(cat_gmv)} category tạo ra 80% GMV (Pareto).")

insights.append(f"[Logistics -> review] Đơn trễ có review TB {late.mean():.2f} so với {ontime.mean():.2f} khi đúng hẹn "
                f"(chênh {ontime.mean() - late.mean():.2f} điểm, Mann-Whitney p = {p_mw:.1e}).")

insights.append(f"[Tập trung seller] Gini GMV = {gini:.2f}; top 10% seller chiếm {top10_share:.1%} GMV; "
                f"{pct_small:.1%} seller có dưới {MIN_ORDERS} đơn.")

insights.append(f"[Quy mô vs chất lượng] Spearman(số đơn, review) = {rho_sz:.2f} -> "
                + ("quy mô gần như không đảm bảo chất lượng." if abs(rho_sz) < 0.2
                   else "có mối liên hệ giữa quy mô và chất lượng."))

insights.append(f"[Nhãn Performance] Xem trước: Good = {pct_good:.1%}, NeedsSupport = {1 - pct_good:.1%} "
                f"-> {'lớp mất cân bằng đáng kể' if min(pct_good, 1 - pct_good) < 0.3 else 'lớp tương đối cân bằng'}.")

insights.append(f"[Phân phối feature] Các feature lệch mạnh (|skew| > 1): {skew[skew.abs() > 1].index.tolist()} "
                f"-> dùng log-transform và qcut.")

for i, s_ in enumerate(insights, 1):
    print(f"Insight {i}: {s_}")
(OUT_DIR / 'insights.txt').write_text('\n'.join(f'Insight {i}: {t}' for i, t in enumerate(insights, 1)), encoding='utf-8')


#### 2.3.9 Bảng "Insight -> Hệ quả cho các bước sau" (điền số liệu từ output thật)

#| # | Insight (điền số liệu từ 2.3.8) | Ý nghĩa nghiệp vụ | Tác động tới bước nào |
#|---|---|---|---|
#| 1 | % đơn chỉ 1 sản phẩm = [X]% | Giỏ hàng quá thưa để tìm luật mua kèm theo đơn | Mục 4.1: mining theo Seller |
#| 2 | Tháng cao điểm = [Y], MoM cao nhất = [Z]% | Có thời vụ/khuyến mãi tác động lên khối lượng đơn | Mục 3: thêm `IsHolidayPeak` vào `Dim_Date`; mục 7.3: hướng mở rộng mining theo mùa |
#| 3 | Top-3 bang chiếm [A]% seller; giao khác bang chậm hơn [B] ngày | Vị trí seller ảnh hưởng logistics | Mục 3.2: `Region` trong `Dim_Geography`; giải thích Performance |
#| 4 | [N] category tạo 80% GMV | Danh mục tập trung theo Pareto | Mục 3.4: chọn category cho truy vấn OLAP mẫu |
#| 5 | Đơn trễ thấp hơn đơn đúng hẹn [D] điểm review (p < 0.05) | Giao hàng là yếu tố chi phối trải nghiệm | Mục 4.5: dùng `late_rate` + `avg_review` làm tiêu chí nhãn |
#| 6 | Gini = [G], top 10% seller = [T]% GMV | Thị trường lệch về ít seller lớn | Mục 5.2: cân nhắc tách mega-seller khỏi clustering |
#| 7 | Spearman(số đơn, review) = [R] | Quy mô có/không đồng nghĩa chất lượng | Mục 5.2.1: lý do phân khúc theo hiệu suất |
#| 8 | Good = [P]% / NeedsSupport = [100-P]% | Nhãn mất cân bằng | Mục 4.6 và 4.8: minsup toàn cục, chọn luật cân bằng 2 lớp |
#| 9 | Feature lệch mạnh = [danh sách] | Phân phối đuôi dài | Mục 4.4 (`qcut`), mục 5.2.2 (`log1p`) |

# **Giả thuyết cần đối chiếu với output thật (không phải kết luận):**
# - Seller tập trung ở một vài bang, đặc biệt bang có nền kinh tế lớn nhất.
# - Đơn giao trễ có review thấp hơn rõ rệt đơn đúng hẹn.
# - Doanh thu tập trung vào một nhóm nhỏ seller và một nhóm nhỏ category.
# - Nếu kết quả thật đi ngược giả thuyết, **hãy trình bày đúng kết quả thật** và nêu giải thích — đó là điểm cộng về tư duy phản biện.

# **Mẫu đoạn nhận xét cho báo cáo (thay [..] bằng số liệu thật):**
# > *"Sau tiền xử lý, bộ dữ liệu gồm [N_orders] đơn đã giao của [N_sellers] seller, GMV [GMV] BRL. Phân tích mô tả cho thấy [pct_single]% đơn chỉ có một sản phẩm, xác nhận việc mining ở mức Seller. Đơn giao trễ có điểm review trung bình thấp hơn [D] điểm so với đơn đúng hẹn (Mann-Whitney, p < 0.05), vì vậy `late_rate` và `avg_review` được chọn làm tiêu chí nhãn Performance. Phân phối GMV theo seller lệch mạnh (Gini = [G]), do đó các đặc trưng quy mô được log-transform và rời rạc hoá theo tần suất bằng nhau (qcut) trước khi mining."*
