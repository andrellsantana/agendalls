"""Gera o ícone do app (AppIcon.appiconset) a partir da caricatura.

Uso: python3 scripts/gerar_icone.py caminho/da/caricatura.jpg
"""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

origem = Image.open(sys.argv[1]).convert("RGB")
destino = Path(__file__).resolve().parent.parent / "AgendALLS/Assets.xcassets/AppIcon.appiconset"
destino.mkdir(parents=True, exist_ok=True)

BASE = 1024
CREME = (237, 229, 213)

def icone_base():
    tela = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    d = int(BASE * 0.86)                 # diâmetro do círculo
    off = (BASE - d) // 2
    circulo = Image.new("RGBA", (d, d), CREME + (255,))
    # caricatura inteira dentro do círculo
    largura = int(d * 322 / 420)
    altura = int(origem.height * largura / origem.width)
    foto = origem.resize((largura, altura), Image.LANCZOS).convert("RGBA")
    # suaviza as laterais da foto para fundir com o creme
    mascara = Image.new("L", (largura, altura), 255)
    md = ImageDraw.Draw(mascara)
    borda = max(1, int(largura * 0.04))
    for i in range(borda):
        v = int(255 * i / borda)
        md.line([(i, 0), (i, altura)], fill=v)
        md.line([(largura - 1 - i, 0), (largura - 1 - i, altura)], fill=v)
    circulo.paste(foto, ((d - largura) // 2, int(d * 30 / 420)), mascara)
    # recorte circular
    mc = Image.new("L", (d * 4, d * 4), 0)
    ImageDraw.Draw(mc).ellipse((0, 0, d * 4 - 1, d * 4 - 1), fill=255)
    mc = mc.resize((d, d), Image.LANCZOS)
    # aro branco
    aro = Image.new("RGBA", (d * 4, d * 4), (0, 0, 0, 0))
    esp = int(d * 4 * 10 / 420)
    ImageDraw.Draw(aro).ellipse((esp // 2, esp // 2, d * 4 - esp // 2, d * 4 - esp // 2), outline=(255, 255, 255, 255), width=esp)
    aro = aro.resize((d, d), Image.LANCZOS)
    circulo = Image.alpha_composite(circulo, aro)
    circulo.putalpha(mc)
    # sombra suave
    sombra = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    ImageDraw.Draw(sombra).ellipse((off, off + int(BASE * 0.015), off + d, off + d + int(BASE * 0.015)), fill=(0, 0, 0, 90))
    sombra = sombra.filter(ImageFilter.GaussianBlur(BASE * 0.02))
    tela = Image.alpha_composite(tela, sombra)
    tela.paste(circulo, (off, off), circulo)
    return tela

base = icone_base()
imagens = []
for tamanho in (16, 32, 128, 256, 512):
    for escala in (1, 2):
        px = tamanho * escala
        nome = f"icone_{tamanho}x{tamanho}@{escala}x.png"
        base.resize((px, px), Image.LANCZOS).save(destino / nome)
        imagens.append({"idiom": "mac", "size": f"{tamanho}x{tamanho}", "scale": f"{escala}x", "filename": nome})

(destino / "Contents.json").write_text(json.dumps({"images": imagens, "info": {"version": 1, "author": "xcode"}}, indent=2))
(destino.parent / "Contents.json").write_text(json.dumps({"info": {"version": 1, "author": "xcode"}}, indent=2))
print("Ícone gerado em", destino)
