import os
from PIL import Image

def merge_directory_images(root_dir='.'):
    # Walk through the root directory and all subdirectories
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Filter out png files, excluding any already generated merged.png
        png_files = [
            f for f in filenames 
            if f.lower().endswith('.png') and f != 'merged.png'
        ]
        
        if not png_files:
            continue
            
        # Sort files alphabetically to maintain order (e.g., frame_0000, frame_0001...)
        png_files.sort()
        
        print(f"Processing: {dirpath}")
        print(f"Layering: {png_files}")
        
        # Open the first image as the base layer
        base_path = os.path.join(dirpath, png_files[0])
        base_img = Image.open(base_path).convert("RGBA")
        
        # Composite each subsequent image on top
        for file in png_files[1:]:
            img_path = os.path.join(dirpath, file)
            img = Image.open(img_path).convert("RGBA")
            base_img = Image.alpha_composite(base_img, img)
            
        # Save the result
        output_path = os.path.join(dirpath, 'merged.png')
        base_img.save(output_path)
        print(f"-> Saved: {output_path}\n")

if __name__ == '__main__':
    merge_directory_images()