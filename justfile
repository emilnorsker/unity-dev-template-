# Unity Development Tasks
set shell := ["bash", "-c"]
set dotenv-load := true


_parse_test_results:
    #!/usr/bin/env bash
    if [ ! -f "test-results.xml" ]; then
        echo "❌ No test results found!"
        exit 1
    fi
    
    # Parse the XML file using xmllint with default values if not found
    TOTAL=$(xmllint --xpath "string(/test-run/@total)" test-results.xml 2>/dev/null || echo "0")
    PASSED=$(xmllint --xpath "string(/test-run/@passed)" test-results.xml 2>/dev/null || echo "0")
    FAILED=$(xmllint --xpath "string(/test-run/@failed)" test-results.xml 2>/dev/null || echo "0")
    SKIPPED=$(xmllint --xpath "string(/test-run/@skipped)" test-results.xml 2>/dev/null || echo "0")
    DURATION=$(xmllint --xpath "string(/test-run/@duration)" test-results.xml 2>/dev/null || echo "0")
    
    # Convert empty strings to 0
    TOTAL=${TOTAL:-0}
    PASSED=${PASSED:-0}
    FAILED=${FAILED:-0}
    SKIPPED=${SKIPPED:-0}
    DURATION=${DURATION:-0}
    
    # Output in a format that can be captured
    echo "$TOTAL:$PASSED:$FAILED:$SKIPPED:$DURATION"


_ensure-license:
    #!/usr/bin/env bash
    LICENSE_PATH=~/.local/share/unity3d/Unity/Unity_lic.ulf
    
    if [ ! -f "$LICENSE_PATH" ]; then
        echo "🔑 No Unity license found at $LICENSE_PATH"
        echo ""
        echo "Please follow these steps:"
        echo "1. Run: unityhub"
        echo "2. Log in with your Unity account"
        echo "3. Go to Preferences > Licenses"
        echo "4. Click Add > Get a free personal license"
        echo ""
        echo "The license file will be created automatically at:"
        echo "$LICENSE_PATH"
        echo ""
        echo "Then run 'just' again to launch Unity"
        exit 1
    fi


default:
    @just --list

# Launch Unity
unity *args: _ensure-license
    unity_editor \
        -username "$UNITY_USERNAME" \
        -password "$UNITY_PASSWORD" \
        -projectPath "$(pwd)/UnityProject" \
        {{args}}

# Run Unity tests and display results
test: _ensure-license
    #!/usr/bin/env bash
    echo "🧪 Running Unity tests..."
    
    # Run the tests
    unity_editor \
        -username "$UNITY_USERNAME" \
        -password "$UNITY_PASSWORD" \
        -projectPath "$(pwd)/UnityProject" \
        -batchmode \
        -runTests \
        -testResults "$(pwd)/test-results.xml" \
        -testPlatform PlayMode
    
    # Get test results
    RESULTS=$(just _parse_test_results)
    IFS=':' read -r TOTAL PASSED FAILED SKIPPED DURATION <<< "$RESULTS"
    
    echo ""
    echo "📊 Test Results Summary:"
    echo "===================="
    
    # Display summary
    echo "✨ Total Tests: $TOTAL"
    echo "✅ Passed: $PASSED"
    echo "❌ Failed: $FAILED"
    echo "⏭️  Skipped: $SKIPPED"
    echo "⏱️  Duration: $DURATION seconds"
    echo ""
    
    # If there are failures, show them
    if [ "$FAILED" -gt 0 ]; then
        echo "Failed Tests:"
        echo "============"
        echo ""
        
        # Get all failed test names
        FAILED_TESTS=$(xmllint --xpath "//test-case[@result='Failed']/@name" test-results.xml 2>/dev/null | tr ' ' '\n' | sed 's/name="\(.*\)"/\1/')
        
        # For each failed test, get its message
        echo "$FAILED_TESTS" | while IFS= read -r test_name; do
            if [ ! -z "$test_name" ]; then
                # Get the failure message for this test
                message=$(xmllint --xpath "string(//test-case[@name='$test_name']//failure/message)" test-results.xml 2>/dev/null | sed 's/\[\[CDATA\[\(.*\)\]\]\>/\1/')
                
                echo "❌ $test_name"
                echo "-------------------"
                echo "$message"
                echo ""
            fi
        done
    fi
    
    # Exit with failure if any tests failed
    [ "$FAILED" -eq 0 ]
