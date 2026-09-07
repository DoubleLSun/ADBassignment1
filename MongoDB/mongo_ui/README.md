# MongoDB Reports UI

Interactive Streamlit interface for the six reports in `MongoDB/mongo_queries`.

## Install

From this folder:

```powershell
pip install -r requirements.txt
```

## Run

Make sure MongoDB is running, then run:

```powershell
streamlit run app.py
```

Open the URL printed by Streamlit, normally `http://localhost:8501`.

The default connection is `mongodb://127.0.0.1:27017` and database `ecommerce_db`. The sidebar allows those values to be changed.
