# Statelessor Frontend Deployment

## Prerequisites
- AWS CLI configured with appropriate permissions
- Node.js and npm installed

## Deployment Commands

Run these commands in sequence:

### 1. Build Production Bundle
```bash
npm run build
```

### 2. Deploy Static Assets
```bash
aws s3 sync build/ s3://statelessor-frontend-bucket/statelessor/ \
  --delete \
  --cache-control "max-age=31536000,public"
```

### 3. Deploy HTML with No Cache
```bash
aws s3 cp build/index.html s3://statelessor-frontend-bucket/statelessor/index.html \
  --cache-control "max-age=0,no-cache,no-store,must-revalidate"
```

## What Each Command Does

- **Step 1**: Creates optimized production build
- **Step 2**: Uploads all assets with 1-year cache headers
- **Step 3**: Uploads HTML with no-cache headers for instant updates

## Environment Variables

Set `REACT_APP_API_URL` to override the default API endpoint:
```bash
export REACT_APP_API_URL=https://your-custom-api-url.com
```

Default: `https://statelessor-api.port2aws.pro`