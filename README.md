# iNaturalist Identifier

A Lightroom Classic plugin that identifies animal species in photos using the iNaturalist API.

---

## Table of Contents

- [Overview](#overview)  
- [Features](#features)  
- [Installation](#installation)  
- [Configuration](#configuration)  
- [Usage](#usage)  
- [Plugin Structure](#plugin-structure)  
- [Dependencies](#dependencies)  
- [Development](#development)  
- [License](#license)
- [If you want support project](#If-you-want-support-the-project)

---

## Overview

The iNaturalist Bird Identifier plugin integrates with Adobe Lightroom Classic to help users automatically identify bird species captured in their photographs. It leverages the iNaturalist API to analyze selected photos and adds species identification tags based on the API's results.

---

## Features

- Send photos from Lightroom to iNaturalist's image recognition API  
- Automatically tag photos with identified bird species  
- Select and tag multiple photos in batch (to be done) 
- View detailed API responses for each image  
- Simple and lightweight plugin using Lua

---

## Installation

1. Download or clone the repository:  
   ```bash
   git clone https://github.com/pbranly/iNaturalistBirdIdentifier.git
Open Lightroom Classic.

Go to File > Plugin Manager.

Click Add and navigate to the cloned iNaturalistBirdIdentifier folder.

Select the folder and confirm to install the plugin.

## Configuration

The plugin requires an iNaturalist API token for authentication:

Obtain an API token by creating an account on iNaturalist.

Create a personal access token from your iNaturalist profile settings.

In Lightroom, open the plugin panel and enter your API token when prompted.

Note: this token is valid 24 hours only

## Usage

Select one or more photos in Lightroom Library.( not tested)

Use the plugin menu to send images to the iNaturalist API for bird species identification.

Review the identification results and select which species tags to apply.

The plugin will tag the photos with species names based on API results.

## Plugin Structure

Info.lua — Plugin metadata and main entry point.

AnimalIdentifier.lua — Handles image uploading and API communication.

call_inaturalist.lua — Manages the iNaturalist API requests and responses.

SelectAndTagResults.lua — User interface for selecting API results and tagging photos.

json.lua — JSON encoding/decoding utility for API data.

## Dependencies

Adobe Lightroom Classic (version compatible with Lua-based plugins)

Internet connection for API requests

Lua standard libraries (bundled with Lightroom plugin environment)

## Development

Feel free to fork and contribute!

Fork the repository.

Make your changes.

Open a pull request describing your improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

Developed by Philippe Branly

### If you want support the project

www.paypal.me/philippebranly



