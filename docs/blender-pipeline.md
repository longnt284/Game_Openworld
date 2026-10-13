# Blender → Godot

Model mẫu được tạo riêng cho dự án: cây thông, đá và trạm ánh sáng. Nguồn chỉnh sửa ở `art/*.blend`, script tái tạo ở `tools/blender/build_assets.py`, file runtime ở `assets/models/*.glb`. `art/.gdignore` ngăn Godot tự nhập `.blend`, giúp máy khác không cần cài Blender để chạy game.

## Tạo lại bộ mẫu

Từ thư mục repo, dùng Blender 5.2.2 LTS (phiên bản đã kiểm tra):

```powershell
blender --background --factory-startup --python tools/blender/build_assets.py
./tools/run.ps1 -Mode test
```

Script chỉ chạy ở chế độ background và ghi đè ba model mẫu của chính nó. Khi đã chỉnh `.blend` thủ công, hãy export model đó trực tiếp; không chạy generator nếu muốn giữ sửa đổi riêng.

## Quy ước model mới

- Đơn vị mét, origin ở chân vật thể; apply rotation/scale trước khi export.
- Dùng Principled BSDF, texture PBR phổ thông; bake các node procedural không được glTF hỗ trợ.
- Export glTF 2.0 định dạng **GLB**, +Y Up; bỏ camera/lights không cần dùng.
- Giữ material và mesh ít, dùng texture theo ngân sách thực tế. Không đưa collider chi tiết cao cho từng cây.
- Thêm đường dẫn trong `AssetLibrary.PATHS`, import trong Godot và chạy test. Scene riêng nên bọc model để thêm gameplay/collision mà không sửa scene import.
- Runtime hiện tạo collider terrain và thân cây bằng code. Model đá là trang trí; beacon kích hoạt bằng khoảng cách.

Tài liệu: [Godot 3D import](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html), [Blender glTF](https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html).
