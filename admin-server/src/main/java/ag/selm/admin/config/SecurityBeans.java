package ag.selm.admin.config;

import ag.selm.admin.web.client.OAuthHttpHeadersProvider;
import jakarta.annotation.Priority;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.CsrfConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.client.AuthorizedClientServiceOAuth2AuthorizedClientManager;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClientService;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import org.springframework.security.web.SecurityFilterChain;

import java.util.Optional;

@Configuration
public class SecurityBeans {

//    @Bean
//    public OAuthHttpHeadersProvider oAuthHttpHeadersProvider(
//            ClientRegistrationRepository clientRegistrationRepository,
//            OAuth2AuthorizedClientService authorizedClientService
//    ) {
//        return new OAuthHttpHeadersProvider(
//                new AuthorizedClientServiceOAuth2AuthorizedClientManager(
//                        clientRegistrationRepository, authorizedClientService)
//        );
//    }
//
//    @Bean
//    @Priority(0)
//    public SecurityFilterChain apiSecurityFilterChain(HttpSecurity http) throws Exception {
//        return http
//                .securityMatchers(customizer -> customizer
//                        .requestMatchers(HttpMethod.POST, "/instances")
//                        .requestMatchers(HttpMethod.DELETE, "/instances/*")
//                        .requestMatchers("/actuator/**"))
//                .oauth2ResourceServer(customizer -> customizer.jwt(Customizer.withDefaults()))
//                .authorizeHttpRequests(customizer -> customizer.requestMatchers("/instances", "/instances/*")
//                        .hasAuthority("SCOPE_metrics_server")
//                        .requestMatchers("/actuator/**").hasAuthority("SCOPE_metrics")
//                        .anyRequest().denyAll())
//                .sessionManagement(customizer -> customizer.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
//                .csrf(CsrfConfigurer::disable)
//                .build();
//    }
//
//    @Bean
//    @Priority(1)
//    public SecurityFilterChain uiSecurityFilterChain(HttpSecurity http) throws Exception {
//        return http
//                .oauth2Client(Customizer.withDefaults())
//                .oauth2Login(Customizer.withDefaults())
//                .authorizeHttpRequests(customizer -> customizer.anyRequest().authenticated())
//                .build();
//    }

    @Bean
    public OAuthHttpHeadersProvider oAuthHttpHeadersProvider(
            ClientRegistrationRepository clientRegistrationRepository,
            OAuth2AuthorizedClientService authorizedClientService
    ) {
        return new OAuthHttpHeadersProvider(
                new AuthorizedClientServiceOAuth2AuthorizedClientManager(
                        clientRegistrationRepository, authorizedClientService)
        );
    }

    /**
     * kubelet probes: должны быть доступны без токена.
     */
    @Bean
    @Priority(0)
    public SecurityFilterChain actuatorHealthSecurityFilterChain(HttpSecurity http) throws Exception {
        return http
                .securityMatcher("/actuator/health/readiness", "/actuator/health/liveness")
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
                .csrf(CsrfConfigurer::disable)
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .build();
    }

    /**
     * SBA API (/instances) и весь actuator (кроме health/*) — только по токену.
     */
    @Bean
    @Priority(1)
    public SecurityFilterChain apiSecurityFilterChain(HttpSecurity http) throws Exception {
        return http
                .securityMatchers(matchers -> matchers
                        .requestMatchers(HttpMethod.POST, "/instances")
                        .requestMatchers(HttpMethod.DELETE, "/instances/*")
                        .requestMatchers("/actuator/**"))
                .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.POST, "/instances").hasAuthority("SCOPE_metrics_server")
                        .requestMatchers(HttpMethod.DELETE, "/instances/*").hasAuthority("SCOPE_metrics_server")
                        .requestMatchers("/actuator/**").hasAuthority("SCOPE_metrics")
                        .anyRequest().denyAll())
                .csrf(CsrfConfigurer::disable)
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .build();
    }

    /**
     * UI: логин через OIDC.
     */
    @Bean
    @Priority(2)
    public SecurityFilterChain uiSecurityFilterChain(HttpSecurity http) throws Exception {
        return http
                .oauth2Client(Customizer.withDefaults())
                .oauth2Login(Customizer.withDefaults())
                .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
                .build();
    }
}
