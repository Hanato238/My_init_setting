# ER図

## tweetデータベース

```mermaid
---
title: "タイトル"
---
erDiagram
    sellers ||--o{ join : ""
    join }o--|| asin : ""
    asin ||--o{ research : ""
    asin ||--o{ image : ""
    research ||--|| conpetition : ""


    sellers {
        bigint seller_id PK "Seller ID"
        varchar seller_name "Seller名"
        varchar shop_url "Shop URL"
        int 5_rate "星5率"
        timestamp deleted_at "削除日時"
        timestamp created_at "作成日時"
        timestamp updated_at "更新日時"
    }

    join {
        bigint join_id PK "ID"
        bigint seller_id FK "Seller ID:sellers.seller_id"
        varchar asin FK "ASIN:asin.asin"
        timestamp deleted_at "削除日時"
        timestamp created_at "作成日時"
        timestamp updated_at "更新日時"
    }

    asin {
        varchar asin PK "ASIN"
        varchar image_url FK "Image URL:image.url"
        varchar ec_url "購入先URL"
        varchar 
        varchar cry "購入通貨"
    }
```