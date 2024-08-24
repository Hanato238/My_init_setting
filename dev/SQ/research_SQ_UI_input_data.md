```mermaid
---
title: "価格・判定等の確認入力作業"
---
sequenceDiagram
    participant users as Users
    participant ss as SpreadSheet
    participant gas as GoogleAppsScript
    participant db as Database

        opt add details    
        gas ->> db : request data 
        db -->> gas : return data
        gas -->> ss : make sheet
        users -->> ss : input data<br/>[unit_price, cry, ec_url] 
        ss ->> gas : call at end
        gas ->> ss :  request input data<br/>[unit_price, cry, ec_url] 
        ss -->> gas : return data<br/>[unit_price, cry, ec_url] 
        gas -->> db : write data<br/>[unit_price, cry, ec_url] 
        gas ->> ss : delete filled sheet<br/>[入力=済]
        end

```
