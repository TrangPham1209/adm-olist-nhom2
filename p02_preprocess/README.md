# Preprocessing & EDA 

**Tiền xử lý** và **Phân tích mô tả (EDA) sau tiền xử lý** của bài toán khai phá dữ liệu Olist (đơn vị phân tích: Seller).

## 1. Nội dung báo cáo

| Mục | Nội dung |
|---|---|
| 1–2 | Mục tiêu, phạm vi, dữ liệu đầu vào (8 bảng, grain) |
| 3 | Tiền xử lý: nhật ký 7 bước, lý do, tác động, rủi ro; dữ liệu thiếu; kiểm tra chất lượng; hạn chế; từ điển cột đầu ra |
| 4.0–4.7 | EDA ở 3 mức grain (order-item / order / seller): KPI, thời gian, địa lý, category & giá, giao hàng & review, thanh toán, seller – 13 insight (Quan sát → Diễn giải → Hệ quả → Độ tin cậy) |
| 4.8–4.9 | Bảng tổng hợp insight → hệ quả cho DW/khai phá/phân loại; hạn chế |

## 2. Cấu trúc thư mục cần có

```
**final_code**/
├── data/                      # 8 file CSV Olist
├── p02_preprocess.py          # tiền xử lý (+ phần Descriptive 2.3.x)
├── p02b_descriptive.py        # (tuỳ chọn) chạy riêng phần mô tả
├── preprocess_out/            # (sinh ra) df_delivered.pkl, prep_log.csv, missing_before_after.csv ...
└── preprocess_figs/           # (sinh ra) prep_overview.png và 02_*.png
```
## 3. Các bước chạy lại

Chạy tại thư mục `final/`. Chạy **cả file** `.py`, không chọn một đoạn rồi bấm Run Code (nếu không sẽ lỗi `NameError: df_delivered`).

**Bước 1 – Có dữ liệu trong `data/`.** Dùng CSV Olist.

**Bước 2 – Tiền xử lý + EDA, sinh hình và dữ liệu sạch:**
```
python p02_preprocess.py
```
Kết quả: `preprocess_out/` (`df_delivered.pkl`, `olist_preprocessed.csv`, `prep_log.csv`, `missing_before_after.csv`, `kpi_summary.csv`, `insights.txt`) và `preprocess_figs/` (11 ảnh PNG).

## 4. Lỗi thường gặp

| Triệu chứng | Nguyên nhân / cách xử lý |
|---|---|
| `FileNotFoundError: data/olist_orders_dataset.csv` | Chưa có CSV trong `data/` hoặc chạy sai thư mục; chạy từ `final/` hoặc đặt `DATA_DIR_OVERRIDE` trong `p01_preprocess.py` |
| `NameError: df_delivered` / `pd` | Đang chạy một đoạn code được chọn; chạy cả file |
| `FileNotFoundError: preprocess_out/df_delivered.pkl` | Chưa chạy Bước 2 |
| `AssertionError: {'khoá'}` ở Bước 3 | Template dùng khoá `[[...]]` chưa được định nghĩa trong `N` |
| Ảnh không hiện trong Word | Thiếu `--resource-path=.` hoặc chạy pandoc sai thư mục |
