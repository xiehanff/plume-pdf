#include "ocr_method_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#include <memory>
#include <string>
#include <thread>
#include <vector>

#include "utils.h"

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResult;
using flutter::MethodChannel;

constexpr char kChannelName[] = "plume_pdf/ocr";
constexpr char kRecognizeMethod[] = "recognizeTextFromImage";

std::string RecognizeTextFromImage(const std::vector<uint8_t>& image_bytes) {
  using namespace winrt;
  using namespace Windows::Globalization;
  using namespace Windows::Graphics::Imaging;
  using namespace Windows::Media::Ocr;
  using namespace Windows::Storage::Streams;

  InMemoryRandomAccessStream stream;
  DataWriter writer(stream);
  writer.WriteBytes(array_view<const uint8_t>(image_bytes));
  writer.StoreAsync().get();
  writer.FlushAsync().get();
  writer.DetachStream();
  stream.Seek(0);

  auto decoder = BitmapDecoder::CreateAsync(stream).get();
  auto bitmap =
      decoder.GetSoftwareBitmapAsync(BitmapPixelFormat::Bgra8,
                                     BitmapAlphaMode::Premultiplied)
          .get();

  OcrEngine engine = OcrEngine::TryCreateFromUserProfileLanguages();
  if (!engine) {
    engine = OcrEngine::TryCreateFromLanguage(Language(L"zh-Hans"));
  }
  if (!engine) {
    engine = OcrEngine::TryCreateFromLanguage(Language(L"en-US"));
  }
  if (!engine) {
    throw hresult_error(E_FAIL, L"Windows OCR is unavailable.");
  }

  auto result = engine.RecognizeAsync(bitmap).get();
  std::string text;
  bool first_line = true;
  for (const auto& line : result.Lines()) {
    const std::string utf8_line = Utf8FromUtf16(line.Text().c_str());
    if (utf8_line.empty()) {
      continue;
    }
    if (!first_line) {
      text += "\n";
    }
    text += utf8_line;
    first_line = false;
  }
  return text;
}

void HandleRecognizeTextFromImage(
    const MethodCall<EncodableValue>& call,
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    result->Error("INVALID_ARGUMENTS", "Missing OCR image bytes.");
    return;
  }

  const auto image_bytes_it = arguments->find(EncodableValue("imageBytes"));
  if (image_bytes_it == arguments->end()) {
    result->Error("INVALID_ARGUMENTS", "Missing OCR image bytes.");
    return;
  }

  const auto* image_bytes =
      std::get_if<std::vector<uint8_t>>(&image_bytes_it->second);
  if (image_bytes == nullptr || image_bytes->empty()) {
    result->Error("INVALID_ARGUMENTS", "Missing OCR image bytes.");
    return;
  }

  const std::vector<uint8_t> copied_image_bytes = *image_bytes;
  std::thread(
      [image_bytes = std::move(copied_image_bytes),
       result = std::move(result)]() mutable {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
        try {
          result->Success(EncodableValue(RecognizeTextFromImage(image_bytes)));
        } catch (const winrt::hresult_error& error) {
          result->Error("OCR_REQUEST_FAILED",
                        Utf8FromUtf16(error.message().c_str()));
        } catch (...) {
          result->Error("OCR_REQUEST_FAILED", "Windows OCR request failed.");
        }
      })
      .detach();
}

}  // namespace

void RegisterOcrMethodChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<MethodChannel<EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const MethodCall<EncodableValue>& call,
         std::unique_ptr<MethodResult<EncodableValue>> result) {
        if (call.method_name() != kRecognizeMethod) {
          result->NotImplemented();
          return;
        }
        HandleRecognizeTextFromImage(call, std::move(result));
      });

  channel.release();
}
