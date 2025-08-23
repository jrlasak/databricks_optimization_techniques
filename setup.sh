#!/bin/bash
# Delta Lake Optimization Project - Environment Setup Script
# This script helps set up the local development environment

set -e  # Exit on any error

echo "🚀 Setting up Delta Lake Optimization Project Environment"
echo "=================================================="

# Check if we're in a virtual environment
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "✅ Virtual environment detected: $VIRTUAL_ENV"
else
    echo "⚠️  No virtual environment detected. Consider creating one:"
    echo "   python -m venv delta_optimization_env"
    echo "   source delta_optimization_env/bin/activate  # Linux/Mac"
    echo "   delta_optimization_env\\Scripts\\activate    # Windows"
    echo ""
    read -p "Continue without virtual environment? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install Python requirements
echo "📦 Installing Python packages..."
if pip install -r requirements.txt; then
    echo "✅ Python packages installed successfully"
else
    echo "❌ Failed to install Python packages"
    exit 1
fi

# Check Jupyter installation
echo "🔍 Checking Jupyter installation..."
if command -v jupyter >/dev/null 2>&1; then
    echo "✅ Jupyter is installed"
    
    # Check if Jupyter is running
    if pgrep -f "jupyter" > /dev/null; then
        echo "ℹ️  Jupyter is already running"
    else
        echo "💡 To start Jupyter: jupyter notebook"
    fi
else
    echo "⚠️  Jupyter not found. Installing..."
    pip install jupyter
fi

# Check for Databricks CLI (optional)
echo "🔍 Checking Databricks CLI..."
if command -v databricks >/dev/null 2>&1; then
    echo "✅ Databricks CLI is installed"
    echo "   Configure with: databricks configure --token"
else
    echo "ℹ️  Databricks CLI not found (optional for local development)"
    echo "   Install with: pip install databricks-cli"
fi

# Create directories if they don't exist
echo "📁 Setting up project directories..."
mkdir -p data/
mkdir -p logs/
mkdir -p results/
echo "✅ Project directories created"

# Display next steps
echo ""
echo "🎉 Environment setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. For Databricks Cloud:"
echo "   • Open Databricks workspace"
echo "   • Import this repository using Repos"
echo "   • Run project.ipynb with a serverless cluster"
echo ""
echo "2. For Local Development:"
echo "   • Start Jupyter: jupyter notebook"
echo "   • Open project.ipynb"
echo "   • Note: Full functionality requires Databricks runtime"
echo ""
echo "3. Additional Resources:"
echo "   • README.md - Complete project documentation"
echo "   • metrics_collection.ipynb - Automated metrics tracking"
echo "   • partitioning_comparison_extension.ipynb - Advanced examples"
echo ""
echo "Happy learning! 🎓"