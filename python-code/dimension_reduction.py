from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
import pandas as pd

audio_features_df = pd.read_csv("data/audio_features.csv")
audio_features_df = audio_features_df.set_index("track_id")

X = audio_features_df.select_dtypes(include=["number"])

X_scaled = StandardScaler().fit_transform(X)

X_3d = PCA(3).fit_transform(X_scaled)

df_3d = pd.DataFrame(X_3d, index=audio_features_df.index, columns=["x", "y", "z"])