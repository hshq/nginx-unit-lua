require 'spec.spec_helper'

describe("PagesController", function()

    describe("#root", function()
        it("responds with a welcome message", function()
            local response = cgi({
                method = 'GET',
                path = "/"
            })
            
            assert.are.same(200, response.status)
            assert.are.same("hello vanilla.", response.body_raw)
        end)
    end)

    describe("#buested", function()
        it("responds with a welcome message for buested", function()
            local response = cgi({
                method = 'GET',
                path = "/index/buested"
            })
            
            assert.are.same(200, response.status)
            assert.are.same("hello buested.", response.body_raw)
        end)
    end)
end)

