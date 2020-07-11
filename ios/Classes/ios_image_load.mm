#import <Flutter/Flutter.h>
#include "ios_image_load.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>

#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

static const uint8_t _jpg_header[] = { 0xff, 0xd8, 0xff, 0xe0 };
static const uint8_t _png_header[] = { 0x89, 0x50, 0x4e, 0x47 };

bool CheckFormat(uint8_t* bytes, const size_t bytes_len, const uint8_t* header) {
  if(bytes_len > 4) {
    for(int index = 0; index < 4; ++index) {
      if(bytes[index] != header[index]) {
        return false;
      }
    }

    return true;
  }

  return false;
}

bool IsJpg(uint8_t* bytes, const size_t bytes_len) {
  return CheckFormat(bytes, bytes_len, _jpg_header);
}

bool IsPng(uint8_t* bytes, const size_t bytes_len) {
  return CheckFormat(bytes, bytes_len, _png_header);
}

std::vector<uint8_t> LoadImageFromByteArray(uint8_t* bytes, const size_t bytes_len, int* out_width,
                                            int* out_height, int* out_channels) {
  CFDataRef bytes_ref = CFDataCreateWithBytesNoCopy(NULL, bytes,
                                                        bytes_len,
                                                        kCFAllocatorNull);
  CGDataProviderRef image_provider = CGDataProviderCreateWithCFData(bytes_ref);
  
  CGImageRef image;
  if(IsPng(bytes, bytes_len)) {
    image = CGImageCreateWithPNGDataProvider(image_provider, NULL, true,
                                             kCGRenderingIntentDefault);
  }
  else if(IsJpg(bytes, bytes_len)) {
    image = CGImageCreateWithJPEGDataProvider(image_provider, NULL, true,
                                              kCGRenderingIntentDefault);
  } else {
    CFRelease(image_provider);
    CFRelease(bytes_ref);
    //fprintf(stderr, "Unknown suffix for file '%s'\n", file_name);
    fprintf(stderr, "Unknown format");
    out_width = 0;
    out_height = 0;
    *out_channels = 0;
    return std::vector<uint8_t>();
  }
  
  int width = (int)CGImageGetWidth(image);
  int height = (int)CGImageGetHeight(image);
  const int channels = 4;
  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
  const int bytes_per_row = (width * channels);
  const int bytes_in_image = (bytes_per_row * height);
  std::vector<uint8_t> result(bytes_in_image);
  const int bits_per_component = 8;

  CGContextRef context = CGBitmapContextCreate(result.data(), width, height,
                                               bits_per_component, bytes_per_row, color_space,
                                               kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  CGColorSpaceRelease(color_space);
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
  CGContextRelease(context);
  CFRelease(image);
  CFRelease(image_provider);
  CFRelease(bytes_ref);
  
  *out_width = width;
  *out_height = height;
  *out_channels = channels;
  return result;
}

std::vector<uint8_t> LoadImageFromFile(const char* file_name,
                                     int* out_width, int* out_height,
                                     int* out_channels) {
  FILE* file_handle = fopen(file_name, "rb");
  fseek(file_handle, 0, SEEK_END);
  const size_t bytes_in_file = ftell(file_handle);
  fseek(file_handle, 0, SEEK_SET);
  std::vector<uint8_t> file_data(bytes_in_file);
  fread(file_data.data(), 1, bytes_in_file, file_handle);
  fclose(file_handle);

  return LoadImageFromByteArray(file_data.data(), bytes_in_file, out_width, out_height, out_channels);
}

NSData *CompressImage(NSMutableData *image, int width, int height, int bytesPerPixel) {
  const int channels = 4;
  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate([image mutableBytes], width, height,
                                               bytesPerPixel*8, width*channels*bytesPerPixel, color_space,
                                               kCGImageAlphaPremultipliedLast | (bytesPerPixel == 4 ? kCGBitmapFloatComponents : kCGBitmapByteOrder32Big));
  CGColorSpaceRelease(color_space);
  if (context == nil) return nil;

  CGImageRef imgRef = CGBitmapContextCreateImage(context);
  CGContextRelease(context);
  if (imgRef == nil) return nil;

  UIImage* img = [UIImage imageWithCGImage:imgRef];
  CGImageRelease(imgRef);
  if (img == nil) return nil;

  return UIImagePNGRepresentation(img);
}
