using CompanyName.MyMeetings.Modules.UserAccess.Infrastructure.IdentityServer;
using IdentityServer4.AccessTokenValidation;
using IdentityServer4.Validation;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CompanyName.MyMeetings.Modules.UserAccess.Infrastructure.Configuration.Identity;

public static class IdentityConfiguration
{
    /// <summary>
    /// <see cref="Authority"/> is the base URL used to fetch OpenID configuration (this process must be reachable
    /// at that URL; inside Docker, use loopback and the in-container port, e.g. <c>http://127.0.0.1:8080</c> when
    /// the host maps <c>5000:8080</c>).
    /// <see cref="TokenIssuer"/>, if set, is written to tokens as the issuer; use the public API URL, e.g.
    /// <c>http://localhost:5000</c>, so it matches the <c>iss</c> claim and client requests.
    /// </summary>
    public static IServiceCollection ConfigureIdentityService(this IServiceCollection services, IConfiguration configuration)
    {
        // Defaults match local "dotnet run" (Kestrel on 5000). Overridden by Meetings_Identity__* in Docker, etc.
        const string defaultAuthority = "http://localhost:5000";
        var authority = configuration["Identity:Authority"] ?? defaultAuthority;
        var tokenIssuer = configuration["Identity:TokenIssuer"] ?? authority;

        services.AddIdentityServer(options => { options.IssuerUri = tokenIssuer; })
            .AddInMemoryIdentityResources(IdentityServerConfig.GetIdentityResources())
            .AddInMemoryApiScopes(IdentityServerConfig.GetApiScopes())
            .AddInMemoryApiResources(IdentityServerConfig.GetApis())
            .AddInMemoryClients(IdentityServerConfig.GetClients())
            .AddInMemoryPersistedGrants()
            .AddProfileService<ProfileService>()
            .AddDeveloperSigningCredential();

        services.AddTransient<IResourceOwnerPasswordValidator, ResourceOwnerPasswordValidator>();

        services.AddAuthentication(IdentityServerAuthenticationDefaults.AuthenticationScheme)
            .AddIdentityServerAuthentication(IdentityServerAuthenticationDefaults.AuthenticationScheme, x =>
            {
                x.Authority = authority;
                x.ApiName = "myMeetingsAPI";
                x.RequireHttpsMetadata = false;
            });

        return services;
    }

    public static IApplicationBuilder AddIdentityService(this IApplicationBuilder app)
    {
        app.UseIdentityServer();
        return app;
    }
}
