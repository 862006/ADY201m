import streamlit as st
import pandas as pd
import numpy as np
import joblib
import json
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent / "output" / "streamlit_data"

st.set_page_config(page_title="Instacart - Demo mô hình", layout="wide")

# Ten cluster xuat tu notebook khong dau, anh xa sang tieng Viet co dau de hien thi
NAME_DISPLAY = {
    "Khach hang VIP": "Khách hàng VIP",
    "Khach hang trung thanh": "Khách hàng trung thành",
    "Khach hang tiem nang": "Khách hàng tiềm năng",
    "Khach hang co nguy co roi bo": "Khách hàng có nguy cơ rời bỏ",
}


@st.cache_resource
def load_models():
    scaler = joblib.load(DATA_DIR / "scaler.joblib")
    kmeans = joblib.load(DATA_DIR / "kmeans.joblib")
    xgb = joblib.load(DATA_DIR / "xgb_model.joblib")
    return scaler, kmeans, xgb


@st.cache_data
def load_data():
    with open(DATA_DIR / "cluster_names.json", encoding="utf-8") as f:
        raw_names = {int(k): v for k, v in json.load(f).items()}
    cluster_names = {k: NAME_DISPLAY.get(v, v) for k, v in raw_names.items()}
    with open(DATA_DIR / "features.json", encoding="utf-8") as f:
        features = json.load(f)
    cluster_ranges = pd.read_csv(DATA_DIR / "cluster_ranges.csv", index_col=0)
    user_feat = pd.read_csv(DATA_DIR / "user_feat_sample.csv", index_col=0)
    prod_catalog = pd.read_csv(DATA_DIR / "prod_catalog.csv", index_col=0)
    return cluster_names, features, cluster_ranges, user_feat, prod_catalog


scaler, kmeans, xgb = load_models()
CLUSTER_NAMES, FEATURES, cluster_ranges, user_feat, prod_catalog = load_data()


def build_row(uid, pid):
    u = user_feat.loc[uid]
    p = prod_catalog.loc[pid]
    src = {**u.to_dict(), **p.to_dict()}
    return [src[f] for f in FEATURES]


user_options = {
    f"Khách hàng {u} (reorder ratio {user_feat.loc[u, 'user_reorder_ratio']:.2f})": u
    for u in user_feat.sort_values("user_total_orders", ascending=False).index
}
prod_options = {
    f"{row.product_name} ({row.department})": pid
    for pid, row in prod_catalog.iterrows()
}

st.title("Instacart Market Basket Analysis — Demo mô hình")
st.caption("K-Means phân khúc khách hàng và XGBoost dự đoán khả năng mua lại sản phẩm")

tab1, tab2, tab3 = st.tabs([
    "Phân khúc khách hàng (K-Means)",
    "Gợi ý mua lại (XGBoost)",
    "So sánh 2 khách hàng",
])

# ---------- TAB 1 : K-MEANS ----------
with tab1:
    st.subheader("Nhập chỉ số RFM của khách hàng")
    c1, c2, c3 = st.columns(3)
    recency = c1.number_input("Recency (số ngày từ lần mua gần nhất)", min_value=0.0, value=10.0, step=1.0)
    frequency = c2.number_input("Frequency (tổng số đơn đã đặt)", min_value=0.0, value=15.0, step=1.0)
    monetary = c3.number_input("Monetary (tổng số sản phẩm đã mua)", min_value=0.0, value=100.0, step=1.0)

    if st.button("Phân nhóm khách hàng", type="primary"):
        x = pd.DataFrame([[recency, frequency, monetary]], columns=["recency", "frequency", "monetary"])
        x_scaled = scaler.transform(x)
        cluster = int(kmeans.predict(x_scaled)[0])
        name = CLUSTER_NAMES[cluster]

        dists = np.linalg.norm(kmeans.cluster_centers_ - x_scaled, axis=1)
        order = np.argsort(dists)

        st.success(f"Khách hàng thuộc nhóm: Cluster {cluster} — {name}")

        st.markdown("**Bằng chứng — khoảng cách tới tâm 4 nhóm (đã chuẩn hóa):**")
        dist_df = pd.DataFrame({
            "Cluster": order,
            "Tên nhóm": [CLUSTER_NAMES[c] for c in order],
            "Khoảng cách": dists[order].round(3),
            "Kết luận": ["Gần nhất (được gán)"] + [f"Xa hơn {dists[c] / dists[order[0]]:.1f} lần" for c in order[1:]],
        })
        st.dataframe(dist_df, hide_index=True, use_container_width=True)

        st.markdown("**Vì sao đúng nhóm này — khoảng giá trị RFM thực tế của nhóm:**")
        r = cluster_ranges.loc[cluster]
        rng_df = pd.DataFrame({
            "Chỉ số": ["Recency", "Frequency", "Monetary"],
            "Giá trị nhập": [recency, frequency, monetary],
            "Khoảng của nhóm": [
                f"{r['recency_min']:.1f} - {r['recency_max']:.1f}",
                f"{r['frequency_min']:.1f} - {r['frequency_max']:.1f}",
                f"{r['monetary_min']:.1f} - {r['monetary_max']:.1f}",
            ],
        })
        st.dataframe(rng_df, hide_index=True, use_container_width=True)

# ---------- TAB 2 : XGBOOST GOI Y ----------
with tab2:
    st.subheader("Chọn khách hàng và sản phẩm")
    uid_label = st.selectbox("Khách hàng", list(user_options.keys()))
    uid = user_options[uid_label]

    chosen_labels = st.multiselect("Giỏ hàng (chọn 3-5 sản phẩm)", list(prod_options.keys()))
    chosen = [prod_options[l] for l in chosen_labels]

    if st.button("Gợi ý sản phẩm mua thêm", type="primary"):
        if not (3 <= len(chosen) <= 5):
            st.warning(f"Vui lòng chọn từ 3 đến 5 sản phẩm (đang chọn {len(chosen)}).")
        else:
            candidates = [pid for pid in prod_catalog.index if pid not in chosen]
            X_cand = pd.DataFrame([build_row(uid, pid) for pid in candidates],
                                   columns=FEATURES, index=candidates)
            probs = xgb.predict_proba(X_cand)[:, 1]
            res = pd.DataFrame({
                "product_name": prod_catalog.loc[candidates, "product_name"].values,
                "department": prod_catalog.loc[candidates, "department"].values,
                "ty_le_mua_lai": probs,
                "ty_le_naive": prod_catalog.loc[candidates, "product_reorder_rate"].values,
            }).sort_values("ty_le_mua_lai", ascending=False).reset_index(drop=True)

            top3_model = set(res.head(3)["product_name"])
            top3_naive = set(res.sort_values("ty_le_naive", ascending=False).head(3)["product_name"])
            trung = len(top3_model & top3_naive)

            st.markdown(f"**Giỏ hàng hiện tại:** {', '.join(prod_catalog.loc[chosen, 'product_name'])}")
            st.markdown("**Top 3 gợi ý mua thêm:**")

            top3 = res.head(3)
            cols = st.columns(3)
            for col, (_, row) in zip(cols, top3.iterrows()):
                col.metric(row["product_name"], f"{row['ty_le_mua_lai'] * 100:.1f}%")
                col.caption(f"Naive (độ phổ biến): {row['ty_le_naive'] * 100:.1f}%")

            st.markdown(f"So sánh với baseline naive: trùng {trung}/3 sản phẩm trong top 3.")
            if trung == 3:
                st.info("Với khách hàng này, model gần như tương đương xếp theo độ phổ biến sản phẩm.")
            else:
                st.info("Model điều chỉnh thứ tự khác với độ phổ biến, do ảnh hưởng từ lịch sử riêng của khách hàng.")

            st.markdown("**Toàn bộ bảng xếp hạng (sắp giảm dần theo model):**")
            show = res.copy()
            show["ty_le_mua_lai"] = (show["ty_le_mua_lai"] * 100).round(1).astype(str) + "%"
            show["ty_le_naive"] = (show["ty_le_naive"] * 100).round(1).astype(str) + "%"
            show = show.rename(columns={
                "product_name": "Sản phẩm",
                "department": "Danh mục",
                "ty_le_mua_lai": "Tỷ lệ mua lại (model)",
                "ty_le_naive": "Tỷ lệ naive (độ phổ biến)",
            })
            st.dataframe(show, hide_index=True, use_container_width=True)

# ---------- TAB 3 : SO SANH 2 KHACH HANG ----------
with tab3:
    st.subheader("So sánh xác suất mua lại giữa 2 khách hàng")
    sorted_users = user_feat.sort_values("user_reorder_ratio")
    default_low, default_high = sorted_users.index[0], sorted_users.index[-1]
    user_labels = list(user_options.keys())
    user_ids = list(user_options.values())

    c1, c2 = st.columns(2)
    ua_label = c1.selectbox("Khách hàng A", user_labels, index=user_ids.index(default_high))
    ub_label = c2.selectbox("Khách hàng B", user_labels, index=user_ids.index(default_low))
    uid_a, uid_b = user_options[ua_label], user_options[ub_label]

    if st.button("So sánh 2 khách hàng", type="primary"):
        if uid_a == uid_b:
            st.warning("Vui lòng chọn 2 khách hàng khác nhau.")
        else:
            prods = prod_catalog.index.tolist()
            Xa = pd.DataFrame([build_row(uid_a, pid) for pid in prods], columns=FEATURES, index=prods)
            Xb = pd.DataFrame([build_row(uid_b, pid) for pid in prods], columns=FEATURES, index=prods)
            pa = xgb.predict_proba(Xa)[:, 1]
            pb = xgb.predict_proba(Xb)[:, 1]

            cmp = pd.DataFrame({
                "product_name": prod_catalog.loc[prods, "product_name"].values,
                "user_A": pa,
                "user_B": pb,
            })
            cmp["chenh_lech"] = (cmp["user_A"] - cmp["user_B"]).abs()
            cmp = cmp.sort_values("chenh_lech", ascending=False).reset_index(drop=True)

            m1, m2, m3 = st.columns(3)
            m1.metric("Reorder ratio - Khách A", f"{user_feat.loc[uid_a, 'user_reorder_ratio']:.2f}")
            m2.metric("Reorder ratio - Khách B", f"{user_feat.loc[uid_b, 'user_reorder_ratio']:.2f}")
            m3.metric("Chênh lệch xác suất TB", f"{cmp['chenh_lech'].mean() * 100:.1f} điểm %")

            chart_df = cmp.set_index("product_name")[["user_A", "user_B"]]
            chart_df.columns = ["Khách A", "Khách B"]
            st.bar_chart(chart_df)

            show = cmp.copy()
            for col in ["user_A", "user_B", "chenh_lech"]:
                show[col] = (show[col] * 100).round(1).astype(str) + "%"
            show = show.rename(columns={
                "product_name": "Sản phẩm",
                "user_A": "Khách A",
                "user_B": "Khách B",
                "chenh_lech": "Chênh lệch",
            })
            st.dataframe(show, hide_index=True, use_container_width=True)
