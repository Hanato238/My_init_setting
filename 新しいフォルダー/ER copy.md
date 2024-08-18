# 商品リサーチ管理DB


```mermaid
---
title: "商品リサーチ"
---
erDiagram
    sellers ||--o{ join : ""
    join }o--|| products : ""
    products ||--o{ research : ""
    research ||--o{ dicision : "asin: products.dicision=true"
    research ||--o{ competitors : ""
    dicision ||--|| purchase : "asin:dicision.final_dicision=true"
    purchase ||--|| deliver : "ASIN:purchase.transfer=true"
    deliver ||--o{ stock : "ASIN:deliver.deliver=true"
    stock ||--o{ shipping :"ASIN:stock.shipping=true"
    analysis }o--o{ shipping : ""



    sellers {
        bigint id PK "Seller ID"
        varchar seller_name "Seller名"
        varchar shop_url "Shop URL"
        int five_star_rate "星5率"
        timestamp deleted_at "削除日時"
        timestamp created_at "作成日時"
    }

    join {
        bigint id PK "ID"
        bigint seller_id FK "Seller ID:sellers.id"
        varchar asin FK "ASIN"
        timestamp deleted_at "削除日時"
        timestamp created_at "作成日時"
        timestamp updated_at "更新日時"
    }

%% 検索時間に依存するdataを分離。productsとresearchへ再編
    products { 
        bigint id PK "商品候補ID"
        varchar asin FK "ASIN:join.asin"
        float weight "商品重量"
        img image "商品画像"
        varchar ec_url "購入先URL"
        float unit_price "購入単価"
        cry cry "通貨単位"
    }

    research {
        bigint id PK "ASIN検索履歴ID"
        varchar asin FK "ASIN:join.asin"
        timestamp create_date "検索日時"
        float three_month_sales "3カ月間販売数"
        int competitors "競合カート数"
        float monthly_sales_per_competitor "カートごと月間販売数"
        int commission "FBA手数料"
        int deposit "入金量"
        float cry_jpy "為替"
        float expected_purchase_price "予想仕入値"
        float expected_profit "予想利益"
        float expexted_roi "予想利益率"
        boolean decision "仕入判定"
    }

%% 競合の情報をtableとして追加
    competitors {
        bigint id PK "競合データID"
        bigint asin FK "ASIN:join.asin"
        bigint research_id FK "research.id"
        varchar seller "販売元"
        boolearm amazon_prime "Amazom Prime商品"
        varchar product_status "商品状態"
        int price "出品価格"
    }

    dicision {
        bigint id PK "仕入れ候補ID"
        varchar asin FK "ASIN:join.asin"
        boolean final_dicision "出品判定"
    }

    purchase {
        bigint id PK "仕入れID"
        varchar asin FK "ASIN:join.asin"
        int quantity "仕入れ数"
        float price "購入単価"
        cry cry "購入通貨"
        boolean transfer "転送状況"
    }

    deliver {
        bigint id PK "納品ID"
        timestamp created_date "到着日時"
        bigint purchase_id FK "仕入れID:purchase.id"
        float transfer_fee "転送量"
        float customs_duty "関税"
        boolean deliver "納品状況"
        float deliver_fee "納品手数料"
    }

    stock {
        bigint id PK "在庫ID"
        bigint deliver_id FK "納品ID:deliver.id"
        varchar asin FK "ASIN:join.asin"
        int quantity "在庫数"
        int sales "販売数"
        timestamp created_date "納品日時"
    }

    shipping {
        bigint id PK "出荷ID"
        timestamp created_date "出荷日時"
        bigint stock_id FK "在庫ID:stock.id"
        int sales "販売数"
        int price "価格"
        int profit "利益"
    }

    analysis {
        bigint id PK "分析ID"
        varchar asin FK "ASIN:join.asin"
        float three_month_roi "過去3カ月利益率"
        boolean restock_dicision "再入荷判定"
    }


```