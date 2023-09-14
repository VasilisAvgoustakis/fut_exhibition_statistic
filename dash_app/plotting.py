import pandas as pd
from dash import Dash, html, dcc, callback, Output, Input
import plotly.graph_objs as go

def plot_total_scans_tk(data):
        # do the right processing to fetched data according to selected graph
    df = pd.DataFrame(data)
    df.columns = ['Token Station', 'Area', 'Scans', 'Archived']
    #print(df)
    df_human = df[(df['Area'] == 'human') &
                  (df['Archived'].isna())]
    df_tech = df[(df['Area'] == 'technology') &
                  (df['Archived'].isna())]
    df_nature = df[(df['Area'] == 'nature') &
                   (df['Archived'].isna())]
    df_interactive = df[(df['Area'] == 'interactive') &
                     (df['Token Station'] != 'gtTokenGenetics0') &
                     (df['Archived'].isna())]
    df_archived_human = df[(df['Archived'].notna()) & (df['Area'] == 'human')]
    df_archived_tech = df[(df['Archived'].notna()) & (df['Area'] == 'technology')]
    df_archived_nature = df[(df['Archived'].notna()) & (df['Area'] == 'nature')]
    df_archived_interactive = df[(df['Archived'].notna()) & (df['Area'] == 'interactive')]

    fig = go.Figure(data=[
        go.Bar(name='Mensch', x=df_human['Token Station'], y=df_human['Scans']),
        go.Bar(name='Technik', x=df_tech['Token Station'], y=df_tech['Scans']),
        go.Bar(name='Natur', x=df_nature['Token Station'], y=df_nature['Scans']),
        go.Bar(name='Interaktiv', x=df_interactive['Token Station'], y=df_interactive['Scans']),
        go.Bar(name='Archived Human', x=df_archived_human['Token Station'], y=df_archived_human['Scans'], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Technik', x=df_archived_tech['Token Station'], y=df_archived_tech['Scans'], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Natur', x=df_archived_nature['Token Station'], y=df_archived_nature['Scans'], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Interaktiv', x=df_archived_interactive['Token Station'], y=df_archived_interactive['Scans'], text='Archiviert', textposition='auto'),
    ]
    )

    return fig

def plot_avg_scans(data):
    df = pd.DataFrame(data)
    df.columns = ['Token Station', 'Area', 'Scans', 'From', 'Up to', 'Months passed', 'Archived', 'Average per Month']

    df_human = df[(df['Area'] == 'human') &
                  (df['Archived'].isna())]
    df_tech = df[(df['Area'] == 'technology') &
                  (df['Archived'].isna())]
    df_nature = df[(df['Area'] == 'nature') &
                   (df['Archived'].isna())]
    df_interactive = df[(df['Area'] == 'interactive') &
                     (df['Token Station'] != 'gtTokenGenetics0') &
                     (df['Archived'].isna())]
    df_archived_human = df[(df['Archived'].notna()) & (df['Area'] == 'human')]
    df_archived_tech = df[(df['Archived'].notna()) & (df['Area'] == 'technology')]
    df_archived_nature = df[(df['Archived'].notna()) & (df['Area'] == 'nature')]
    df_archived_interactive = df[(df['Archived'].notna()) & (df['Area'] == 'interactive')]

    x_axis = 'Token Station'
    y_axis = 'Average per Month'

    fig = go.Figure(data=[
        go.Bar(name='Mensch', x=df_human[x_axis], y=df_human[y_axis]),
        go.Bar(name='Technik', x=df_tech[x_axis], y=df_tech[y_axis]),
        go.Bar(name='Natur', x=df_nature[x_axis], y=df_nature[y_axis]),
        go.Bar(name='Interaktiv', x=df_interactive[x_axis], y=df_interactive[y_axis]),
        go.Bar(name='Archived Human', x=df_archived_human[x_axis], y=df_archived_human[y_axis], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Technik', x=df_archived_tech[x_axis], y=df_archived_tech[y_axis], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Natur', x=df_archived_nature[x_axis], y=df_archived_nature[y_axis], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Interaktiv', x=df_archived_interactive[x_axis], y=df_archived_interactive[y_axis], text='Archiviert', textposition='auto'),
    ]
    )

    return fig

plotters =[plot_total_scans_tk, plot_avg_scans] #test