# EDD Download Deploy Action

Deploy downloads to Easy Digital Downloads powered WordPress sites with automated packaging, changelog support, and Slack notifications.

## Features

- Automated ZIP file generation with proper structure
- Support for `.distignore` file exclusions
- Automatic changelog detection from `changelog.txt`
- Version detection from tags or package.json
- Dry-run mode for testing
- Slack notifications for successful deployments
- Secure API authentication

## Quick Start

```yaml
name: Deploy to EDD

on:
  push:
    tags:
      - "*"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: sultann/edd-download-deploy@v1
        with:
          site_url: 'https://example.com'
          api_key: ${{ secrets.EDD_KEY }}
          api_token: ${{ secrets.EDD_TOKEN }}
          item_id: 123
```

## Requirements

**Plugin Installation**: Install [EDD Download Deploy Plugin](https://github.com/sultann/edd-download-deploy-plugin) on your WordPress site.

**GitHub Secrets**: Add the following secrets to your repository's settings under `Settings > Secrets and Variables > Actions`:

- `EDD_KEY` - EDD API key (from `Downloads > Tools > API Keys` in WordPress admin)
- `EDD_TOKEN` - EDD API token (from `Downloads > Tools > API Keys` in WordPress admin)
- `SLACK_WEBHOOK` - (Optional) Slack webhook URL for deployment notifications

## Configuration

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `site_url` | WordPress site URL | Yes | - |
| `api_key` | EDD API key | Yes | - |
| `api_token` | EDD API token | Yes | - |
| `item_id` | EDD download ID | Yes | - |
| `slug` | Download slug | No | Repository name |
| `version` | Release version | No | Tag name or package.json |
| `dry_run` | Preview deployment without uploading | No | `false` |
| `slack_webhook` | Slack webhook URL for notifications | No | - |
| `slack_message` | Custom Slack message | No | Auto-generated |

### Outputs

| Output | Description |
|--------|-------------|
| `version` | Version number used for deployment |
| `zip_path` | Path to generated ZIP file |

## Common Use Cases

### Basic Deployment

Deploy when a tag is pushed:

```yaml
name: Deploy to EDD

on:
  push:
    tags:
      - "*"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: sultann/edd-download-deploy@v1
        with:
          site_url: 'https://example.com'
          api_key: ${{ secrets.EDD_KEY }}
          api_token: ${{ secrets.EDD_TOKEN }}
          item_id: 123
```

### With Slack Notifications

Get notified in Slack when deployment succeeds:

```yaml
- uses: sultann/edd-download-deploy@v1
  with:
    site_url: 'https://example.com'
    api_key: ${{ secrets.EDD_KEY }}
    api_token: ${{ secrets.EDD_TOKEN }}
    item_id: 123
    slack_webhook: ${{ secrets.SLACK_WEBHOOK }}
```

### With Custom Slug and Version

Override slug and version:

```yaml
- uses: sultann/edd-download-deploy@v1
  with:
    site_url: 'https://example.com'
    api_key: ${{ secrets.EDD_KEY }}
    api_token: ${{ secrets.EDD_TOKEN }}
    item_id: 123
    slug: 'my-custom-slug'
    version: '2.0.0'
```

### Testing with Dry Run

Preview what would be deployed without actually uploading:

```yaml
- uses: sultann/edd-download-deploy@v1
  with:
    site_url: 'https://example.com'
    api_key: ${{ secrets.EDD_KEY }}
    api_token: ${{ secrets.EDD_TOKEN }}
    item_id: 123
    dry_run: true
```

## Excluding Files from Release

Create a `.distignore` file to exclude files and directories from the release package:

```
/.git
/.github
/node_modules
/tests

.distignore
.gitignore
composer.json
composer.lock
package.json
package-lock.json
phpunit.xml
```

## Changelog Support

The action automatically detects and includes changelog content if you have a `changelog.txt` file in your repository root. This changelog will be submitted to your EDD site along with the release.

## How It Works

The action follows these steps:

1. Validates required inputs (API credentials, item ID, version)
2. Copies files to a temporary build directory
3. Applies exclusions from `.distignore` file
4. Removes empty directories
5. Creates a ZIP file with proper structure
6. Reads changelog from `changelog.txt` (if exists)
7. Uploads ZIP file and changelog to your EDD site via API
8. Sends Slack notification (if configured)

## License

Our GitHub Actions are available for use and remix under the MIT license.
