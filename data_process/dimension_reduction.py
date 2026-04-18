import numpy as np
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
import pandas as pd

audio_features_df = pd.read_csv("data/audio_features.csv")
audio_features_df = audio_features_df.set_index("track_id")
audio_features_df.dropna(inplace=True)

X = audio_features_df.select_dtypes(include=["number"])

print(X.isna().sum())
print(X.isin([float("inf"), float("-inf")]).sum())

X_scaled = StandardScaler().fit_transform(X)

X_3d = PCA(3).fit_transform(X_scaled)

df_3d = pd.DataFrame(X_3d, index=audio_features_df.index, columns=["x", "y", "z"])
print(df_3d.isna().sum())
print(df_3d.isin([float("inf"), float("-inf")]).sum())
df_3d = df_3d.dropna()
df_3d.to_csv("data/reduced_dim.csv", index=True)