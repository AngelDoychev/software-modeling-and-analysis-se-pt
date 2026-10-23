"""Малък помощен модул за генериране на .drawio (mxGraph XML) файлове."""
from html import escape


class Diagram:
    def __init__(self, name):
        self.name = name
        self.cells = []
        self._id = 1

    def _nid(self):
        self._id += 1
        return f"n{self._id}"

    def vertex(self, value, x, y, w, h, style, parent="1"):
        cid = self._nid()
        self.cells.append(
            f'<mxCell id="{cid}" value="{escape(value, quote=True)}" style="{style}" vertex="1" parent="{parent}">'
            f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        return cid

    def edge(self, src, tgt, style, value="", points=None):
        cid = self._nid()
        pts = ""
        if points:
            pts = '<Array as="points">' + "".join(f'<mxPoint x="{x}" y="{y}"/>' for x, y in points) + "</Array>"
        self.cells.append(
            f'<mxCell id="{cid}" value="{escape(value, quote=True)}" style="{style}" edge="1" parent="1" '
            f'source="{src}" target="{tgt}"><mxGeometry relative="1" as="geometry">{pts}</mxGeometry></mxCell>')
        return cid

    def edge_label(self, edge_id, text, pos, offset_y=-12):
        """етикет върху ребро; pos е от -1 (начало) до 1 (край)"""
        cid = self._nid()
        self.cells.append(
            f'<mxCell id="{cid}" value="{escape(text, quote=True)}" '
            f'style="edgeLabel;html=1;align=center;verticalAlign=middle;resizable=0;points=[];fontSize=12;fontStyle=1;labelBackgroundColor=#ffffff;" '
            f'vertex="1" connectable="0" parent="{edge_id}">'
            f'<mxGeometry x="{pos}" relative="1" as="geometry"><mxPoint y="{offset_y}" as="offset"/></mxGeometry></mxCell>')

    def xml(self):
        body = "".join(self.cells)
        return ('<mxfile host="app.diagrams.net" agent="drawio" version="24.7.17">'
                f'<diagram id="{self.name}" name="{escape(self.name)}">'
                '<mxGraphModel dx="1600" dy="900" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" '
                'arrows="1" fold="1" page="0" pageScale="1" pageWidth="1600" pageHeight="1200" math="0" shadow="0">'
                f'<root><mxCell id="0"/><mxCell id="1" parent="0"/>{body}</root>'
                '</mxGraphModel></diagram></mxfile>')

    def save(self, path):
        with open(path, "w", encoding="utf-8") as f:
            f.write(self.xml())
