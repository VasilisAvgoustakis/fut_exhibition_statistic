import plotly.graph_objs as go

import numpy as np
import os
import base64


def graph_path(x, y, point_times):

    with open(os.getcwd() + "/tokenmap.png", "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode()

    # Add the prefix that plotly will want when using the string as source
    encoded_image = "data:image/png;base64," + encoded_string

    fig = go.Figure()

    # Add image
    img_width = 2380
    img_height = 1992
    fig.add_layout_image(
        x=0,
        sizex=img_width,
        y=0,
        sizey=img_height,
        xref="x",
        yref="y",
        opacity=1.0,
        layer="below",
        source=encoded_image,

    )

    fig.update_xaxes(showgrid=False, range=(0, img_width))
    fig.update_yaxes(showgrid=False, scaleanchor='x', range=(img_height, 0))

    for i in x:
        # draw times on the right side
        fig.add_trace(go.Scatter(x=np.array(x[x.index(i)]), y=np.array(y[x.index(i)]),
                                 mode='markers',
                                 name='Start ' + point_times[x.index(i)],
                                 marker={'size': 12, 'symbol': "x-dot",
                                         'color': "blue"}))
    # draw lines
    for e in x:
        if x.index(e) < len(x) - 1:
            x_zero = e
            y_zero = y[x.index(e)]
            x_one = x[x.index(e) + 1]
            y_one = y[x.index(e) + 1]

            fig.add_shape(type='line', xref='x', yref='y',
                          x0=x_zero, x1=x_one, y0=y_zero, y1=y_one, line_color="red")
    # Set dragmode and newshape properties; add modebar buttons
    fig.update_layout(
        dragmode='drawrect',
        newshape=dict(line_color='cyan'),
        title_text='Exhibition Paths',
        width=1200, height=900
    )

    return fig
