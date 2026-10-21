# Phân tích mô tả và thăm dò dữ liệu: Olist E-commerce Data Analysis

## Giới thiệu

Phần 4.1, 4.2 dùng **Python** để phân tích bộ dữ liệu **Olist E-commerce Dataset**, tập trung vào dữ liệu đơn hàng, sản phẩm, thanh toán, vận chuyển và đánh giá của khách hàng.
Mục tiêu chính là tìm hiểu cấu trúc và chất lượng dữ liệu, thực hiện **Descriptive Statistics** và **Exploratory Data Analysis (EDA)** để khám phá đặc điểm dữ liệu và mối quan hệ giữa các biến.

---

## Analysis Map

```text
Raw Data (Olist)
│
├── Data Understanding
│   ├── Attribute Classification
│   ├── Schema Relationship
│   └── Dataset Overview
│
├── Data Profiling
│   ├── Missing Values
│   ├── Duplicate Records
│   └── Data Quality Assessment
│
├── Descriptive Statistics
│   ├── Numerical Variables
│   ├── Payment Types
│   ├── Product Categories
│   └── Order Status & Review Score
│
├── Exploratory Data Analysis (EDA)
│   ├── Distribution Analysis
│   │   ├── Histogram
│   │   ├── KDE
│   │   └── Boxplot
│   │
│   ├── Outlier Analysis
│   │
│   ├── Bivariate Analysis
│   │   ├── Delivery Days vs Review Score
│   │   ├── Price vs Freight Value
│   │   └── Review by Payment Type
│   │
│   └── Correlation Analysis
│       └── Spearman Correlation Matrix
│
└── Findings & Discussion
```

---

## Dataset

Bộ dữ liệu Olist gồm **9 bảng**:

- Orders
- Order Items
- Customers
- Sellers
- Products
- Payments
- Reviews
- Geolocation
- Product Category Translation

Các bảng được liên kết thông qua các khóa như `order_id`, `customer_id`, `product_id` và `seller_id`. 【1-fde208】

---

## Nội dung phân tích

Project thực hiện các bước chính:

- Khảo sát cấu trúc dữ liệu
- Kiểm tra missing values và duplicate records
- Đánh giá chất lượng dữ liệu
- Thống kê mô tả các biến
- Phân tích phân phối bằng Histogram, KDE và Boxplot
- Phát hiện giá trị ngoại lệ bằng IQR
- Phân tích mối quan hệ giữa các biến
- Phân tích tương quan Spearman
- Trực quan hóa và tổng hợp kết quả

---

## Công nghệ sử dụng

- Python
- Pandas
- NumPy
- Matplotlib
- Seaborn
- SciPy

---

## Cách chạy project

### 1. Clone repository

```bash
git clone <repository-url>
cd <project-folder>
```

### 2. Cài đặt các thư viện cần thiết

Nếu project có file `requirements.txt`:

```bash
pip install -r requirements.txt
```

### 3. Chuẩn bị dữ liệu

Đặt các file `.csv` của **Olist E-commerce Dataset** vào thư mục dữ liệu được sử dụng trong project.

### 4. Chạy file Python

```bash
p1_descriptive&eda.py
```
---

## Kết quả chính

Một số kết quả nổi bật từ quá trình phân tích:

- Phần lớn đơn hàng có trạng thái `delivered`.
- Đánh giá 5 sao chiếm tỷ lệ cao nhất.
- `price`, `freight_value` và `delivery_days` có phân phối lệch phải.
- Dữ liệu có các giá trị nằm ngoài ngưỡng IQR.
- `price` và `total_payment` có tương quan dương mạnh.
- `delivery_days` có xu hướng tương quan âm với `review_score`. 【1-fde208】

---

## Ghi chú

Project được thực hiện phục vụ mục đích **học tập và phân tích dữ liệu**.
Các giá trị ngoại lệ được xác định bằng phương pháp IQR và không mặc định được xem là lỗi dữ liệu.
