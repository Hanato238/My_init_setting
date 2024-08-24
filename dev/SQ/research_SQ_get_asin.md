
```mermaid
---
title: 'sellerリストから商品リスト取得'
---
sequenceDiagram
    participant db as Database
    participant cf as CloudFunctions
    participant keepa as Keepa

        opt 定期実行 : ASIN検索＝sellers.create_join(id), 商品マスタ追加=join.add_product_master(asin)
            cf ->> db : request sellerID at seller
            db -->> cf : return sellerID
            cf ->> keepa : search ASIN by sellerID
            keepa -->> cf : return ASIN
            cf -->> db : write ASIN at join, add ASIN to products_master
        end
```