#include <vector>

std::vector<uint8_t> LoadImageFromByteArray(uint8_t* bytes,
											const size_t bytes_len,
											int* out_width,
                                            int* out_height,
											int* out_channels);

std::vector<uint8_t> LoadImageFromFile(const char* file_name,
						 int* out_width,
						 int* out_height,
						 int* out_channels);

NSData *CompressImage(NSMutableData*,
						 int width,
						 int height,
             int bytesPerPixel);

