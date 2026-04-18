import pandas as pd
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans

df = pd.read_csv("../data/reduced_dim.csv")
X = df[['x', 'y', 'z']]

kmeans = KMeans(n_clusters=3, random_state=42, n_init='auto')
df['cluster'] = kmeans.fit_predict(X)
centroids = kmeans.cluster_centers_

fig = plt.figure(figsize=(16, 12))
cmap = 'Dark2'

ax1 = fig.add_subplot(221, projection='3d')
scatter = ax1.scatter(df['x'], df['y'], df['z'], c=df['cluster'], cmap=cmap, s=20, alpha=0.6)
ax1.scatter(centroids[:, 0], centroids[:, 1], centroids[:, 2],
            c='red', s=300, marker='X', edgecolor='white', linewidth=2, label='Centroids')
ax1.set_title('3D View: KMeans (k=3)')
ax1.set_xlabel('X')
ax1.set_ylabel('Y')
ax1.set_zlabel('Z')
ax1.legend()

ax2 = fig.add_subplot(222)
ax2.scatter(df['x'], df['y'], c=df['cluster'], cmap=cmap, s=15, alpha=0.5)
ax2.scatter(centroids[:, 0], centroids[:, 1], c='red', s=200, marker='X', edgecolor='white')
ax2.set_title('Top-Down View (X vs Y)')
ax2.set_xlabel('X')
ax2.set_ylabel('Y')
ax2.grid(True, linestyle='--', alpha=0.3)

ax3 = fig.add_subplot(223)
ax3.scatter(df['x'], df['z'], c=df['cluster'], cmap=cmap, s=15, alpha=0.5)
ax3.scatter(centroids[:, 0], centroids[:, 2], c='red', s=200, marker='X', edgecolor='white')
ax3.set_title('Side View (X vs Z)')
ax3.set_xlabel('X')
ax3.set_ylabel('Z')
ax3.grid(True, linestyle='--', alpha=0.3)

ax4 = fig.add_subplot(224)
ax4.scatter(df['y'], df['z'], c=df['cluster'], cmap=cmap, s=15, alpha=0.5)
ax4.scatter(centroids[:, 1], centroids[:, 2], c='red', s=200, marker='X', edgecolor='white')
ax4.set_title('Front View (Y vs Z)')
ax4.set_xlabel('Y')
ax4.set_ylabel('Z')
ax4.grid(True, linestyle='--', alpha=0.3)

cbar_ax = fig.add_axes([0.92, 0.15, 0.02, 0.7])
cbar = fig.colorbar(scatter, cax=cbar_ax, ticks=[0, 1, 2])
cbar.set_label('Cluster ID')

plt.subplots_adjust(wspace=0.2, hspace=0.3)
plt.show()