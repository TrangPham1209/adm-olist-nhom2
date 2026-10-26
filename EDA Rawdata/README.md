# Olist E-commerce: Descriptive Analysis & EDA

Dự án thực hiện thống kê mô tả và khám phá dữ liệu trên bộ **Brazilian E-Commerce Public Dataset by Olist**.

## Nội dung phân tích

1. Đọc và chuẩn hóa 9 bảng dữ liệu CSV.
2. Mô tả cấu trúc, khóa và đơn vị quan sát.
3. Phân loại thuộc tính.
4. Kiểm tra dữ liệu khuyết và dòng trùng lặp.
5. Tạo Master DataFrame ở cấp độ mặt hàng.
6. Thống kê mô tả biến định lượng và định tính.
7. Phân tích phân phối đơn biến.
8. Phát hiện ngoại lệ theo quy tắc 1,5 × IQR.
9. Phân tích mối quan hệ hai biến.
10. Phân tích tương quan hạng Spearman.

## Cấu trúc thư mục

```text
olist-descriptive-eda/
├── data/
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_customers_dataset.csv
│   ├── olist_sellers_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── product_category_name_translation.csv
│   ├── olist_order_payments_dataset.csv
│   ├── olist_order_reviews_dataset.csv
│   └── olist_geolocation_dataset.csv
├── 01_eda_output/
│   ├── figures/
│   └── tables/
├── p1_descriptive_eda.ipynb
├── requirements.txt
├── .gitignore
└── README.md
```

## Chuẩn bị dữ liệu

Tải bộ dữ liệu Olist từ nguồn được phép sử dụng, sau đó đặt đúng 9 tệp CSV vào thư mục `data/` theo tên trong cấu trúc trên.

> Gói GitHub-ready này không đính kèm dữ liệu gốc. Cách này giúp repository nhẹ hơn và tránh phân phối lại dữ liệu khi chưa kiểm tra điều khoản của nguồn.

## Cài đặt

Yêu cầu Python 3.10 trở lên.

```bash
python -m venv .venv
```

Kích hoạt môi trường trên Windows:

```bash
.venv\Scripts\activate
```

Kích hoạt môi trường trên macOS/Linux:

```bash
source .venv/bin/activate
```

Cài các thư viện:

```bash
python -m pip install -r requirements.txt
```

## Chạy notebook

```bash
jupyter notebook p1_descriptive_eda.ipynb
```

Sau đó chọn **Run All**. Notebook đọc dữ liệu từ `./data` và tự động tạo kết quả tại:

- `01_eda_output/figures`: biểu đồ PNG.
- `01_eda_output/tables`: bảng kết quả CSV.

## Lưu ý khi đưa lên GitHub

- `.gitignore` mặc định không đưa dữ liệu CSV và output được tạo tự động lên GitHub.
- Nếu cần công khai các bảng kết quả hoặc biểu đồ để minh họa, sửa `.gitignore` rồi chọn lọc tệp cần commit.
- Không đổi tên 9 tệp CSV nếu chưa cập nhật dictionary `raw_files` trong notebook.
