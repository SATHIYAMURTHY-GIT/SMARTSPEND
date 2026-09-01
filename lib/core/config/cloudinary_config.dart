const String cloudinaryCloudName = 'dko0uefqk';
const String cloudinaryUnsignedUploadPreset = 'smartspend_receipts';

final Uri cloudinaryUploadUri = Uri.https(
  'api.cloudinary.com',
  '/v1_1/$cloudinaryCloudName/image/upload',
  {'upload_preset': cloudinaryUnsignedUploadPreset},
);
