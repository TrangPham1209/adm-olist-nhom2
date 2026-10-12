# Đồ án cuối kỳ Advanced Data Mining - Olist
# Đồ án cuối kỳ: EDA → Tiền xử lý → Data Warehouse (Snowflake + Data Cube) → Pattern Mining (3+1 thuật toán) → Classification
## Dataset: Brazilian E-Commerce Public Dataset by Olist — Đơn vị phân tích: **Seller**

### Tổng quan nhanh

| | |
|---|---|
| **Đề tài** | Khai phá luật kết hợp trên hồ sơ **Seller** của sàn Olist: Data Warehouse Snowflake → Pattern Mining (3+1 thuật toán) → Phân loại bằng đặc trưng sinh từ luật |
| **Dữ liệu** | Brazilian E-Commerce Public Dataset by Olist — 8 file CSV (Drive của nhóm: `https://drive.google.com/drive/folders/19hxqzei43tE8DW-QwclDAMsoFucSGFR_`) |
| **Ngôn ngữ / công cụ** | Python ≥ 3.10; pandas, scikit-learn, mlxtend, statsmodels, scipy, DuckDB, matplotlib, seaborn; Graphviz (`dot`); `gdown` để tải dữ liệu |
| **Thời gian chạy** | ≈ 3–4 phút trên dữ liệu 70k đơn (laptop thường); chủ yếu ở bước p06/p07 (15 fold × khai phá lại) |
| **Đầu ra** | `figs/*.png` (hình), `out/*.csv|txt` (bảng kết quả), `out/olist_dw.duckdb` (kho dữ liệu) |


## Ma trận đáp ứng yêu cầu bài cuối kỳ

| # | Yêu cầu | Mục | Trạng thái |
|---|---|---|---|
| 1 | Truy vấn nghiệp vụ theo nhu cầu → tạo data cube | 3.1, 3.5 | 4 nhu cầu (CEO, Category, Logistics, Seller) + cube đầy đủ 2³ cuboid, kiểm tra nhất quán |
| 2 | Trực quan hoá DW: Fact/Dim → **Snowflake** (như Tableau) | 3.2–3.4 | Sơ đồ snowflake + sơ đồ quy trình + bảng đối chiếu thao tác Tableau ↔ SQL |
| 3 | Trực quan hoá **tiền xử lý** | 2.4 | Funnel số dòng, kiểm tra fan-out (GMV), outlier trước/sau, missing trước/sau |
| 4 | Chọn **3 thuật toán + 1 advanced**, so sánh thực nghiệm | 4.6 | Apriori, FP-Growth, ECLAT + CHARM-closed đa chiều (không chọn constraint-based, có lập luận) |
| 5 | 3 luật mỗi thuật toán → % transaction phủ (không so tốc độ) → 9 (+3) luật | 4.7 | Bảng 12 luật + biểu đồ độ phủ train/test |
| 6 | Số feature **trước/sau** khai phá luật, feature nào bị loại | 4.8 | Bảng 10 → 7 → 10 feature, lý do loại từng feature |
| 7 | 3 luật → 3 feature mới → bổ sung vào cleaned dataset; chọn **1 phương pháp tốt nhất** | 4.9, 5.4 | So sánh 5 cách xếp hạng luật + đối chứng "không luật" |
| 8 | Ghi rõ grouping/rời rạc hoá liên tục → rời rạc, **Feature minsup** | 4.3 | 4 bước explicit + Feature-minsup 5% |
| 9 | Correlation trước khi sinh luật | 4.2 | Heatmap Spearman + quy tắc loại theo MI |
| 10 | **Minsup toàn cục** (không tính riêng từng tập) | 4.4 | Quét minsup, 1 ngưỡng duy nhất cho mọi lớp và mọi fold |
| 11 | CBA-RG → CBA-CB bằng sklearn, 2–3 mô hình | 5.1 | Logistic Regression, Decision Tree, Random Forest |
| 12 | Assess F1, recall, accuracy… | 5.2 | + precision, macro-F1, recall từng lớp, AUC |
| 13 | Có luật tốt hơn không dùng luật? | 5.2, 5.6 | Trả lời bằng bằng chứng (hold-out + 15 fold) |
| 14 | Kiểm định thống kê | 5.5 | Friedman, Wilcoxon+Holm, Nadeau–Bengio, McNemar, Mann–Whitney/χ² |
| 15 | Phương pháp mới | 5.4 | **RuleScore** (điểm tổng hợp weighted-χ² kiểu CMAR) |
| 16 | 3 kết quả so sánh: không luật / Apriori / FP-Growth | 5.2 | Bảng hold-out + CV |


## README — List-down các steps chạy lại toàn bộ đồ án
Phần này mô tả **từng bước** để một người chưa từng thấy dự án có thể tái tạo toàn bộ kết quả: từ tải dữ liệu (`download_data.py`) đến báo cáo cuối. Mỗi bước ghi rõ: *làm gì → lệnh → kết quả mong đợi → lỗi thường gặp*.

### Bước 1 — Cấu trúc thư mục sau khi giải nén

```
final_code/
├── download_data.py   # BƯỚC 2: tải 8 CSV thật từ Google Drive
├── make_data_big.py   # (dự phòng) sinh dữ liệu GIẢ LẬP cùng schema
├── p01_preprocess.py … p08_stats.py, lib_rules.py   # các bước phân tích (mục 3–5 bên dưới)
├── run_all.sh         # chạy toàn bộ theo thứ tự
├── requirements.txt
├── data/              # (sinh ra) 8 CSV Olist
├── out/               # (sinh ra) bảng kết quả, DuckDB
└── figs/              # (sinh ra) hình dùng trong báo cáo
```

### Bước 2 — Lấy dữ liệu: `download_data.py`

**2.1 Cách tự động (khuyến nghị).** Script dùng thư viện `gdown` tải cả thư mục Drive về `data/`, gom mọi CSV ra thẳng `data/` (vì `gdown` có thể tạo thư mục con) và kiểm tra đủ 8 file:

```bash
pip install gdown            # đã có trong requirements.txt
python download_data.py
```

Nội dung script (đọc để hiểu nó làm gì từng dòng):

```python
# Tải bộ Olist thật từ thư mục Google Drive về data/ rồi kiểm tra đủ 8 file.
# Cách chạy:  pip install gdown && python download_data.py
# Thoát mã 1 nếu tải lỗi hoặc thiếu file (để run_all.sh biết mà cảnh báo).
# LƯU Ý: chưa được kiểm thử trong môi trường làm bài (Google Drive bị chặn ở đó).
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
print('OK — đủ 8 file CSV trong data/')
```

**Kết quả mong đợi (cuối màn hình):**
```
Đã có: ['olist_customers_dataset', 'olist_order_items_dataset', ... ]
OK — đủ 8 file CSV trong data/
```
8 file cần có: `olist_orders_dataset.csv`, `olist_order_items_dataset.csv`, `olist_customers_dataset.csv`, `olist_sellers_dataset.csv`, `olist_products_dataset.csv`, `olist_order_payments_dataset.csv`, `olist_order_reviews_dataset.csv`, `product_category_name_translation.csv`. (File `olist_geolocation_dataset.csv` không bắt buộc.)

**Cách script xử lý lỗi:** nếu tải lỗi hoặc thiếu file → in danh sách file thiếu và **thoát với mã 1** (không âm thầm chạy tiếp).

**Lỗi thường gặp của bước 2:**

| Hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `Access denied` / `Cannot retrieve the public link` | Thư mục Drive chưa để chế độ **"Anyone with the link – Viewer"** | Chủ thư mục mở *Share → General access → Anyone with the link* |
| Dừng ở 50 file / báo giới hạn | `gdown` giới hạn thư mục lớn | Dùng cách 2.2 |
| `Too many users have viewed or downloaded` | Drive giới hạn lượt tải | Đợi 24 giờ hoặc dùng cách 2.2 từ bản sao Drive của bạn |
| Báo `THIẾU: [...]` | Thư mục không đủ 8 CSV (hoặc file là `.zip`) | Giải nén zip vào `data/`, chạy lại để kiểm tra |


**2.2 Kiểm tra nhanh dữ liệu đã đúng chưa:**
```python
import pandas as pd
o = pd.read_csv('data/olist_orders_dataset.csv'); i = pd.read_csv('data/olist_order_items_dataset.csv')
print(len(o), len(i), o.order_status.value_counts().to_dict())
```

### Bước 3 — Brief chạy từng bước (để debug)

| Bước | Lệnh | Làm gì | Đầu ra chính | Dấu hiệu chạy đúng |
|---|---|---|---|---|
| 3.1 | `python p01_preprocess.py` | Join đúng grain, lọc `delivered`, gộp payment/dedup review, xử lý thiếu/outlier; **vẽ tiền xử lý** | `figs/prep_overview.png`, `out/df_delivered.pkl`, `out/prep_log.csv` | `duplicated(order_id,order_item_id): 0`; **GMV "đúng grain" = GMV "gốc"** |
| 3.2 | `python p02_dw.py` | Tạo DDL **Snowflake** (12 bảng) và nạp ETL vào DuckDB | `out/olist_dw.duckdb` | In số dòng từng bảng; `Fact_OrderItem` = số dòng cuối của p01 |
| 3.3 | `python p03_cube.py` | Chạy 4 truy vấn nghiệp vụ N1–N4 và data cube 2³ cuboid | `out/seller_cube.csv`, `figs/dw_cube.png` | Dòng cuối: `apex = tổng cuboid đáy = GMV fact` (assert) |
| 3.4 | `python p04_diagrams.py` | Sinh sơ đồ Snowflake và sơ đồ quy trình (Graphviz) | `figs/dw_snowflake.png`, `figs/dw_pipeline.png` | In `ok` |
| 3.5 | `python p05_mining.py` | Tương quan → rời rạc hoá → feature-minsup → minsup toàn cục → 3+1 thuật toán → 12 luật + % phủ → feature trước/sau | `out/selected_rules.pkl`, `out/feature_table.csv`, `figs/mining_*.png`, `figs/rules_coverage.png`(sinh ở p08) | 3 thuật toán cho cùng số itemset (`True`); bảng 12 luật |
| 3.6 | `python p06_classify.py` | CBA-CB: 7 cấu hình × 3 mô hình, 15 fold, **mining trong từng fold** | `out/cv_results.pkl`, `out/cv_summary.csv` | In `fold 0/5/10 xong` rồi bảng tổng hợp |
| 3.7 | `python p07_extra.py` | Thí nghiệm k luật (3/10/30) và so sánh phương pháp chọn luật | `out/extra_B.csv`, `out/extra_C.csv` | In hai bảng B, C |
| 3.8 | `python p08_stats.py` | Hold-out, McNemar, Friedman, Wilcoxon–Holm, Nadeau–Bengio, Mann–Whitney; vẽ hình | `out/holdout.csv`, `out/pairwise.csv`, `figs/clf_boxplot.png`, `figs/rules_coverage.png` | In các bảng kiểm định |

**Thứ tự là bắt buộc** (p02 cần `df_delivered.pkl` của p01; p03 cần DuckDB của p02; p05 cần `seller_cube.csv` của p03; p06–p08 cần kết quả p05).

### Bước 4 — Cập nhật báo cáo bằng số liệu thật (nếu trước đó dùng dữ liệu giả lập)

1. Mở các file trong `out/` và hình trong `figs/` để lấy số mới.
2. Sửa các con số cứng trong các mục: 2.4 (funnel, GMV), 3.5 (số ô cuboid, tổng GMV), 4.1 (tỉ lệ Good/NeedsSupport, số seller), 4.2 (feature bị loại do tương quan), 4.7–4.8 (12 luật, % phủ, feature bị loại), 5.2–5.6 (kết quả phân loại và kiểm định), 7.1.
3. **Đọc lại kết luận 5.6/7.1**: nếu trên dữ liệu thật luật *có* cải thiện (p đã hiệu chỉnh < 0,05), phải sửa câu "không cải thiện" cho khớp; ngược lại cũng vậy.
4. Xoá cảnh báo "dữ liệu giả lập" ở đầu tài liệu khi đã dùng dữ liệu thật.

### Bước 5 — Các tham số có thể chỉnh

| Tham số | Vị trí | Mặc định | Ý nghĩa |
|---|---|---|---|
| Ngưỡng gán nhãn Good | `p05_mining.py`, `p06_classify.py` (`avg_review >= 4.0`) | 4.0 | Dữ liệu thật lệch hơn → cân nhắc đổi ngưỡng; phải sửa ở **cả hai** file |
| Số đơn tối thiểu mỗi seller | `n_orders >= 10` | 10 | Seller ít đơn → `avg_review` không đáng tin |
| Minsup toàn cục / minconf | `MINSUP, MINCONF` trong `p05_mining.py` | 5% / 60% | Xem biểu đồ quét `figs/mining_minsup.png` |
| Feature minsup | `FEATURE_MINSUP` (p05) và `0.05` trong `rule_features` (p06) | 5% | Item hiếm hơn ngưỡng bị loại |
| Số fold × lặp | `RepeatedStratifiedKFold(n_splits=5, n_repeats=3)` | 5×3 | Tăng lặp → kiểm định chắc hơn nhưng chậm hơn |
| Hạt ngẫu nhiên | `random_state` | 42 / 2024 | Giữ nguyên để kết quả tái lập được |

### Bước 6 — Xử lý sự cố chung

| Hiện tượng | Cách xử lý |
|---|---|
| `FileNotFoundError: data/olist_...csv` | Chưa xong bước 2; chạy `ls data/` kiểm tra đủ 8 file |
| `FileNotFoundError: out/df_delivered.pkl` (hoặc `seller_cube.csv`, `mining_meta.pkl`…) | Chạy sai thứ tự — chạy lại từ p01 |
| `AssertionError: Bang chua map vung` ở p02 | Dữ liệu có mã bang ngoài 27 bang Brazil → thêm vào dict `REGION` |
| `_duckdb.CatalogException ... main key table` | Bản cũ của DB còn sót; p02 đã tự xoá `out/olist_dw.duckdb` — nếu file đang bị mở bởi chương trình khác, đóng nó rồi chạy lại |
| p06 chạy rất lâu | Giảm `n_repeats` từ 3 xuống 1 để thử nhanh |
| Mục 1–2 của tài liệu (EDA/descriptive, code cũ) báo không thấy CSV | Các đoạn code ở mục 1–2 đọc CSV bằng tên file trần: chạy chúng từ trong thư mục `data/` (`cd data`) |


### Bước 7 — Cách đọc kết quả (gợi ý cho người đọc) ===> CẦN CHỈNH LẠI CHO ĐÚNG USE CASE

1. Hình tiền xử lý → `figs/prep_overview.png`. 
2. Hình Data Warehouse → `figs/dw_snowflake.png`, `figs/dw_pipeline.png`, `figs/dw_cube.png`. 
3. 12 luật + % phủ → bảng ở mục 4.7 và `figs/rules_coverage.png`.
4. Feature trước/sau → mục 4.8 (`out/feature_table.csv`).
5. So sánh không luật / Apriori / FP-Growth → mục 5.2; kiểm định → 5.5; kết luận → 5.6.
